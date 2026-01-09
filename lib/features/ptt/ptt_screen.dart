import 'package:flutter/material.dart';
import 'audio_service.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/message_model.dart';
import '../../core/bluetooth/nearby_service.dart';

class PttScreen extends StatefulWidget {
  const PttScreen({super.key});

  @override
  State<PttScreen> createState() => _PttScreenState();
}

class _PttScreenState extends State<PttScreen> {
  final AudioService _audioService = AudioService();
  bool recording = false;

  @override
  void initState() {
    super.initState();
    _audioService.init();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    setState(() => recording = true);
    final file = await _audioService.recordPTT();
    setState(() => recording = false);

    try {
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);
      final payload = "AUDIO:$base64Audio";

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final message = MessageModel(
        id: const Uuid().v4(),
        payload: payload,
        priority: 2, // Medium priority for voice? Or 3? Let's say 2.
        status: 'local',
        lat: position.latitude,
        lng: position.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final db = await AppDatabase.database;
      await db.insert('messages', message.toMap());

      NearbyService().broadcast(jsonEncode(message.toMap()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio Saved & Synced')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push To Talk')),
      body: Center(
        child: ElevatedButton(
          onPressed: recording ? null : _record,
          child: Text(recording ? 'Recording...' : 'Hold to Speak (5s)'),
        ),
      ),
    );
  }
}
