import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/database/app_database.dart';
import '../../core/database/message_model.dart';
import '../../core/bluetooth/nearby_service.dart';
import 'dart:convert';

class SosController {
  static Future<void> sendSOS({
    required int priority,
    required String label,
  }) async {
    // 10 second safety delay
    await Future.delayed(const Duration(seconds: 10));

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final message = MessageModel(
      id: const Uuid().v4(),
      payload: label,
      priority: priority,
      status: 'local',
      lat: position.latitude,
      lng: position.longitude,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final db = await AppDatabase.database;
    await db.insert('messages', message.toMap());

    // Broadcast to mesh
    NearbyService().broadcast(jsonEncode(message.toMap()));
  }
}
