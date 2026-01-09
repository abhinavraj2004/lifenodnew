import 'package:record/record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> init() async {
    // Check and request permission if needed
    if (!await _audioRecorder.hasPermission()) {
      // Handle permission denial
    }
  }

  Future<File> recordPTT() async {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/ptt.m4a';

    // Start recording
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    // Record for 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    // Stop recording
    await _audioRecorder.stop();

    return File(path);
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
