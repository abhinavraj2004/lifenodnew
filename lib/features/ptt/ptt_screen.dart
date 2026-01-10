import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/message_model.dart';
import '../../core/bluetooth/nearby_service.dart';
import 'audio_service.dart';

import '../sos/sos_controller.dart';

class PttScreen extends StatefulWidget {
  const PttScreen({super.key});

  @override
  State<PttScreen> createState() => _PttScreenState();
}

class _PttScreenState extends State<PttScreen> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isSending = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  final AudioService _audioService = AudioService();
  late AnimationController _waveController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _audioService.init();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    final path = await _audioService.startRecording();
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start recording')),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _waveController.repeat();
    _pulseController.repeat(reverse: true);

    // Timer for UI updates and max duration limit (30s)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() => _recordingSeconds++);

      // Auto-stop at 30 seconds
      if (_recordingSeconds >= 30) {
        _stopAndSend();
      }
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _waveController.stop();
    _pulseController.stop();

    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    try {
      final file = await _audioService.stopRecording();

      if (file == null) {
        throw Exception("Recording returned null file");
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);
      final payload = "AUDIO:$base64Audio";

      // Get location with fallback
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
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
        payload: payload,
        priority: 2,
        status: 'local',
        lat: position.latitude,
        lng: position.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Track this message as sent by us (import SosController at top)
      // We add to static set directly since SosController is in same package
      SosController.sentMessageIds.add(messageId);

      final db = await AppDatabase.database;
      await db.insert('messages', message.toMap());
      NearbyService().broadcast(jsonEncode(message.toMap()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Voice note broadcasted!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Header
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00b4d8), Color(0xFF0077b6)],
              ).createShader(bounds),
              child: const Text(
                'PUSH TO TALK',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hold to record voice message',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),

            // Main PTT Button Area
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (context, constraints) {
                  // Scale button based on available height, maxing at original size
                  final size = constraints.maxHeight * 0.5;
                  final buttonSize = size.clamp(100.0, 160.0);
                  final glowSize = (size + 40).clamp(140.0, 200.0);

                  return GestureDetector(
                    onTapDown: (_) {
                      if (!_isRecording && !_isSending) _startRecording();
                    },
                    onTapUp: (_) {
                      if (_isRecording) _stopAndSend();
                    },
                    onTapCancel: () {
                      if (_isRecording) {
                        setState(() => _isRecording = false);
                        _waveController.stop();
                        _pulseController.stop();
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer waves
                        if (_isRecording)
                          ...List.generate(3, (index) {
                            return AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                final delay = index * 0.3;
                                final value =
                                    (_waveController.value + delay) % 1.0;
                                return Container(
                                  width: (glowSize) + (value * 80),
                                  height: (glowSize) + (value * 80),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00b4d8)
                                          .withValues(alpha: 1.0 - value),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),

                        // Main button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? buttonSize + 20 : buttonSize,
                          height: _isRecording ? buttonSize + 20 : buttonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _isRecording
                                  ? [
                                      const Color(0xFFe63946),
                                      const Color(0xFFa4161a)
                                    ]
                                  : [
                                      const Color(0xFF00b4d8),
                                      const Color(0xFF0077b6)
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? const Color(0xFFe63946)
                                        : const Color(0xFF00b4d8))
                                    .withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            size: buttonSize * 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Status
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_isRecording)
                    Text(
                      '${5 - _recordingSeconds}s remaining',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFe63946),
                      ),
                    )
                  else if (_isSending)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Broadcasting...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Tap to start recording',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
