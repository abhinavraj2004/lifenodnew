import 'package:record/record.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> init() async {
    // Check and request permission if needed
    if (!await _audioRecorder.hasPermission()) {
      debugPrint('Audio recording permission not granted');
    }
  }

  /// Start recording audio
  Future<String?> startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      return path;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return null;
    }
  }

  /// Stop recording and return the file
  Future<File?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        return File(path);
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  /// Record for a specific duration (legacy method)
  Future<File> recordPTT() async {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/ptt.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    // Record for 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    await _audioRecorder.stop();

    return File(path);
  }

  /// Play audio from a file path
  Future<void> playFromFile(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
      debugPrint('Playing audio from: $path');
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// Play audio from base64 encoded data
  Future<void> playFromBase64(String base64Data) async {
    try {
      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/received_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await tempFile.writeAsBytes(bytes);

      // Play the file
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      debugPrint('Playing received audio');
    } catch (e) {
      debugPrint('Error playing base64 audio: $e');
    }
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
  }

  /// Check if currently playing
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
