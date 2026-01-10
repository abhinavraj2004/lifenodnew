import 'package:nearby_connections/nearby_connections.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'gossip_engine.dart';

/// Connection status for mesh network
enum MeshStatus {
  inactive,
  searching,
  connected,
}

/// Callback types for connection events
typedef ConnectionCallback = void Function(int peerCount);
typedef MessageCallback = void Function(Map<String, dynamic> message);

class NearbyService {
  static final NearbyService _instance = NearbyService._internal();

  factory NearbyService() {
    return _instance;
  }

  NearbyService._internal();

  final Strategy strategy = Strategy.P2P_CLUSTER;
  final Set<String> connectedEndpoints = {};
  final Set<String> _pendingConnections =
      {}; // Track pending connection requests
  final GossipEngine gossipEngine = GossipEngine();
  String _deviceName = ''; // Store device name for connection requests

  bool _isRunning = false;
  MeshStatus _status = MeshStatus.inactive;

  // Callbacks for UI updates
  final List<ConnectionCallback> _connectionListeners = [];
  final List<MessageCallback> _messageListeners = [];

  /// Get current mesh status
  MeshStatus get status => _status;

  /// Get connected peer count
  int get peerCount => connectedEndpoints.length;

  /// Check if mesh is running
  bool get isRunning => _isRunning;

  /// Add a listener for connection changes
  void addConnectionListener(ConnectionCallback callback) {
    _connectionListeners.add(callback);
  }

  /// Remove a connection listener
  void removeConnectionListener(ConnectionCallback callback) {
    _connectionListeners.remove(callback);
  }

  /// Add a listener for incoming messages
  void addMessageListener(MessageCallback callback) {
    _messageListeners.add(callback);
  }

  /// Remove a message listener
  void removeMessageListener(MessageCallback callback) {
    _messageListeners.remove(callback);
  }

  /// Notify all connection listeners
  void _notifyConnectionListeners() {
    for (final listener in _connectionListeners) {
      listener(connectedEndpoints.length);
    }
  }

  /// Notify all message listeners
  void _notifyMessageListeners(Map<String, dynamic> message) {
    for (final listener in _messageListeners) {
      listener(message);
    }
  }

  /// Start the mesh network service
  Future<void> start() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint(
          'Nearby Connections only supported on Android/iOS. Skipping for ${Platform.operatingSystem}');
      return;
    }

    if (_isRunning) {
      debugPrint('NearbyService already running');
      return;
    }

    _isRunning = true;
    _status = MeshStatus.searching;
    _notifyConnectionListeners();

    // Use same service ID for all devices
    const serviceId = 'com.rescuemesh.nearby';

    // Generate a unique but short endpoint name for this device
    _deviceName = 'RM${DateTime.now().millisecondsSinceEpoch % 10000}';

    try {
      // Start advertising - make this device discoverable
      final advertisingStarted = await Nearby().startAdvertising(
        _deviceName, // Endpoint name (device identifier)
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId, // Important: use consistent service ID
      );
      debugPrint(
          'Advertising started: $advertisingStarted (name: $_deviceName)');

      // Start discovery - find other devices
      final discoveryStarted = await Nearby().startDiscovery(
        _deviceName, // Our username when requesting connection
        strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: serviceId, // Must match advertising service ID
      );
      debugPrint(
          'Discovery started: $discoveryStarted (serviceId: $serviceId)');
    } catch (e) {
      debugPrint('Error starting NearbyService: $e');
      _isRunning = false;
      _status = MeshStatus.inactive;
      _notifyConnectionListeners();
    }
  }

  /// Stop the mesh network service
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      connectedEndpoints.clear();
      _isRunning = false;
      _status = MeshStatus.inactive;
      _notifyConnectionListeners();
      debugPrint('NearbyService stopped');
    } catch (e) {
      debugPrint('Error stopping NearbyService: $e');
    }
  }

  /// Handle connection initiation
  void _onConnectionInitiated(String id, ConnectionInfo info) {
    debugPrint('Connection initiated with: $id (${info.endpointName})');
    // Always accept connections in mesh mode
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayload,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  /// Handle connection result
  void _onConnectionResult(String id, Status status) {
    debugPrint('Connection result for $id: $status');
    if (status == Status.CONNECTED) {
      connectedEndpoints.add(id);
      _status = MeshStatus.connected;
      _notifyConnectionListeners();
      debugPrint(
          'Connected to peer: $id. Total peers: ${connectedEndpoints.length}');

      // Initiate handshake to sync messages
      gossipEngine.handleHandshake(id, this);
    } else {
      connectedEndpoints.remove(id);
      if (connectedEndpoints.isEmpty) {
        _status = MeshStatus.searching;
      }
      _notifyConnectionListeners();
      debugPrint('Failed to connect to: $id');
    }
  }

  /// Handle disconnection
  void _onDisconnected(String id) {
    debugPrint('Disconnected from peer: $id');
    connectedEndpoints.remove(id);
    if (connectedEndpoints.isEmpty) {
      _status = MeshStatus.searching;
    }
    _notifyConnectionListeners();
  }

  /// Handle endpoint found during discovery
  void _onEndpointFound(String id, String userName, String serviceId) {
    debugPrint('Found endpoint: $id ($userName) - Service: $serviceId');

    // Skip if already connected or pending
    if (connectedEndpoints.contains(id) || _pendingConnections.contains(id)) {
      debugPrint('Already connected/pending to $id, skipping');
      return;
    }

    _pendingConnections.add(id);

    // Request connection to discovered peer
    Nearby().requestConnection(
      _deviceName.isNotEmpty ? _deviceName : 'RescueMesh',
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: (endpointId, status) {
        _pendingConnections.remove(endpointId);
        _onConnectionResult(endpointId, status);
      },
      onDisconnected: _onDisconnected,
    ).then((_) {
      debugPrint('Connection request sent to: $id');
    }).catchError((e) {
      _pendingConnections.remove(id);
      debugPrint('Error requesting connection to $id: $e');
    });
  }

  /// Handle endpoint lost
  void _onEndpointLost(String? id) {
    debugPrint('Lost endpoint: $id');
  }

  /// Handle incoming payload
  void _onPayload(String id, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        final str = utf8.decode(payload.bytes!);
        debugPrint(
            'Received data from $id: ${str.substring(0, str.length > 100 ? 100 : str.length)}...');

        // Process through gossip engine
        gossipEngine.processData(id, str, this);

        // Try to parse and notify listeners
        try {
          final decoded = jsonDecode(str);
          if (decoded is Map<String, dynamic>) {
            _notifyMessageListeners(decoded);
          }
        } catch (_) {
          // Not a JSON message, that's okay
        }
      } catch (e) {
        debugPrint('Error processing payload from $id: $e');
      }
    }
  }

  /// Handle payload transfer updates
  void _onPayloadTransferUpdate(String id, PayloadTransferUpdate update) {
    // Can add progress tracking here if needed
  }

  /// Send data to a specific peer
  void send(String id, String data) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (!connectedEndpoints.contains(id)) {
      debugPrint('Cannot send to $id - not connected');
      return;
    }

    try {
      Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(data)));
      debugPrint('Sent ${data.length} bytes to $id');
    } catch (e) {
      debugPrint('Error sending to $id: $e');
    }
  }

  /// Broadcast data to all connected peers
  void broadcast(String data) {
    if (connectedEndpoints.isEmpty) {
      debugPrint('No peers connected for broadcast');
      return;
    }

    debugPrint('Broadcasting to ${connectedEndpoints.length} peers');
    for (final id in connectedEndpoints) {
      send(id, data);
    }
  }
}
