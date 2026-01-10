import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../database/message_model.dart';

/// Callback for when a new SOS message is received
typedef MessageReceivedCallback = void Function(MessageModel message);

class GossipEngine {
  final Set<String> seenMessages = {};

  // Callbacks for incoming messages
  static final List<MessageReceivedCallback> _messageListeners = [];

  // Singleton instance
  static final GossipEngine _instance = GossipEngine._internal();
  factory GossipEngine() => _instance;
  GossipEngine._internal() {
    _initSeenMessages();
  }

  Future<void> _initSeenMessages() async {
    try {
      final db = await AppDatabase.database;
      final messages = await db.query('messages', columns: ['id']);
      for (final row in messages) {
        seenMessages.add(row['id'] as String);
      }
      debugPrint(
          'GossipEngine: Initialized with ${seenMessages.length} seen messages');
    } catch (e) {
      debugPrint('GossipEngine: Error initializing seen messages: $e');
    }
  }

  /// Add a listener for incoming messages
  static void addMessageListener(MessageReceivedCallback callback) {
    _messageListeners.add(callback);
  }

  /// Remove a message listener
  static void removeMessageListener(MessageReceivedCallback callback) {
    _messageListeners.remove(callback);
  }

  /// Notify all listeners of a new message
  static void _notifyMessageListeners(MessageModel message) {
    debugPrint(
        'GossipEngine: Notifying ${_messageListeners.length} listeners of new message');
    for (final listener in _messageListeners) {
      try {
        listener(message);
      } catch (e) {
        debugPrint('Error in message listener: $e');
      }
    }
  }

  Future<void> handleHandshake(String peerId, dynamic service) async {
    try {
      final db = await AppDatabase.database;
      final messages = await db.query('messages');

      final ids = messages.map((m) => m['id']).toList();
      final payload = jsonEncode(ids);
      service.send(peerId, payload);
      debugPrint(
          'GossipEngine: Sent ${ids.length} message IDs in handshake to $peerId');
    } catch (e) {
      debugPrint('GossipEngine: Error in handleHandshake: $e');
    }
  }

  Future<void> processData(String peerId, String data, dynamic service) async {
    try {
      final dynamic decoded = jsonDecode(data);

      if (decoded is List) {
        // Handshake: They sent us their IDs. Send messages they don't have.
        debugPrint(
            'GossipEngine: Received handshake with ${decoded.length} IDs from $peerId');

        final theirIds = Set<String>.from(decoded.cast<String>());
        final db = await AppDatabase.database;
        final myMessages = await db.query('messages');

        int sentCount = 0;
        for (final row in myMessages) {
          final id = row['id'] as String;
          if (!theirIds.contains(id)) {
            // They are missing this message. Send it.
            final msg = MessageModel(
              id: id,
              payload: row['payload'] as String,
              priority: row['priority'] as int,
              status: row['status'] as String,
              lat: row['lat'] as double,
              lng: row['lng'] as double,
              timestamp: row['timestamp'] as int,
            );
            service.send(peerId, jsonEncode(msg.toMap()));
            sentCount++;
          }
        }
        debugPrint('GossipEngine: Sent $sentCount missing messages to $peerId');
      } else if (decoded is Map) {
        // Incoming Message
        debugPrint(
            'GossipEngine: Received message from $peerId: ${decoded['payload']}');

        final msg = MessageModel(
          id: decoded['id'] as String,
          payload: decoded['payload'] as String,
          priority: decoded['priority'] as int,
          status: 'relayed',
          lat: (decoded['lat'] as num).toDouble(),
          lng: (decoded['lng'] as num).toDouble(),
          timestamp: decoded['timestamp'] as int,
        );
        await receiveMessage(msg, service);
      }
    } catch (e) {
      debugPrint('GossipEngine: Error processing data: $e');
    }
  }

  Future<void> receiveMessage(MessageModel msg, dynamic service) async {
    if (seenMessages.contains(msg.id)) {
      debugPrint('GossipEngine: Already seen message ${msg.id}, skipping');
      return;
    }

    // Check if message is tombstoned (deleted)
    if (await AppDatabase.isTombstoned(msg.id)) {
      debugPrint(
          'GossipEngine: Message ${msg.id} is tombstoned (deleted), skipping');
      return;
    }

    seenMessages.add(msg.id);
    debugPrint(
        'GossipEngine: New message received: ${msg.payload} (priority: ${msg.priority})');

    try {
      final db = await AppDatabase.database;
      await db.insert(
        'messages',
        msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      debugPrint('GossipEngine: Message saved to database');

      // IMPORTANT: Notify listeners about the incoming message
      _notifyMessageListeners(msg);

      // Rebroadcast to all neighbours
      final batteryLevel = await Battery().batteryLevel;
      if (batteryLevel < 15) {
        debugPrint(
            'GossipEngine: Low battery ($batteryLevel%), skipping relay');
        return;
      }

      // Broadcast to other peers
      service.broadcast(jsonEncode(msg.toMap()));
      debugPrint('GossipEngine: Message relayed to other peers');
    } catch (e) {
      debugPrint('GossipEngine: Error receiving message: $e');
    }
  }
}
