import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/message_model.dart';
import '../../core/bluetooth/nearby_service.dart';
import 'dart:convert';

class SosController {
  // Track IDs of messages we sent to avoid showing popup for our own messages
  static final Set<String> sentMessageIds = {};

  /// Check if a message was sent by us
  static bool isSelfSent(String messageId) {
    return sentMessageIds.contains(messageId);
  }

  /// Send an SOS message. Returns the message ID if successful, null if failed.
  static Future<String?> sendSOS({
    required int priority,
    required String label,
  }) async {
    try {
      // Get current location
      Position position;
      try {
        // First try to get the last known position to be quick
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
          // Trigger a fresh update in background for next time
          Geolocator.getCurrentPosition()
              .then((p) => debugPrint('Location updated in background: $p'));
        } else {
          // If no last known, try to get current with timeout
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy:
                LocationAccuracy.medium, // Reduce accuracy for speed
            timeLimit: const Duration(seconds: 5),
          );
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
        // Final fallback
        position = Position(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      final messageId = const Uuid().v4();
      final message = MessageModel(
        id: messageId,
        payload: label,
        priority: priority,
        status: 'local',
        lat: position.latitude,
        lng: position.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Track this message as sent by us
      sentMessageIds.add(messageId);

      // Save to local database
      final db = await AppDatabase.database;
      await db.insert('messages', message.toMap());
      debugPrint('SOS saved to database: $messageId');

      // Broadcast to mesh network
      final service = NearbyService();
      final jsonData = jsonEncode(message.toMap());

      if (service.peerCount > 0) {
        service.broadcast(jsonData);
        debugPrint('SOS broadcast to ${service.peerCount} peers');
      } else {
        debugPrint('No peers connected - SOS saved locally only');
      }

      return messageId;
    } catch (e) {
      debugPrint('Error sending SOS: $e');
      return null;
    }
  }
}
