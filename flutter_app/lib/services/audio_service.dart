import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Audio recording service using the `record` package.
///
/// Handles microphone audio capture and provides a stream
/// of audio amplitudes for UI visualization.
class AudioService {
  AudioService();

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _stateSub;
  bool _isRecording = false;

  /// Whether audio is currently being recorded.
  bool get isRecording => _isRecording;

  /// Check if the device has a microphone and permission is granted.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  /// Start audio recording.
  ///
  /// Records audio as PCM 16kHz mono for optimal STT compatibility.
  /// Returns a stream of audio data bytes.
  Future<Stream<List<int>>> startRecording() async {
    final bool permitted = await _recorder.hasPermission();
    if (!permitted) {
      throw const AudioServiceException('Microphone permission denied');
    }

    const RecordConfig config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );

    final Stream<List<int>> stream = await _recorder.startStream(config);
    _isRecording = true;

    debugPrint('[AudioService] Recording started (PCM 16kHz mono)');
    return stream;
  }

  /// Pause audio recording.
  Future<void> pauseRecording() async {
    if (_isRecording) {
      await _recorder.pause();
      debugPrint('[AudioService] Recording paused');
    }
  }

  /// Resume audio recording.
  Future<void> resumeRecording() async {
    await _recorder.resume();
    debugPrint('[AudioService] Recording resumed');
  }

  /// Stop audio recording.
  Future<void> stopRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
      debugPrint('[AudioService] Recording stopped');
    }
  }

  /// Get the current recording amplitude (for UI visualization).
  Future<Amplitude> getAmplitude() async {
    return _recorder.getAmplitude();
  }

  /// Dispose the audio service and release resources.
  Future<void> dispose() async {
    _stateSub?.cancel();
    await stopRecording();
    _recorder.dispose();
  }
}

/// Exception thrown by AudioService operations.
class AudioServiceException implements Exception {
  /// Create an AudioServiceException with a message.
  const AudioServiceException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'AudioServiceException: $message';
}
