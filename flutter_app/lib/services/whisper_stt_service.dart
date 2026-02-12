import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:meetmind/native/whisper_bindings.dart';

/// High-level Whisper STT service with isolate-based inference.
///
/// Provides a simple API for on-device speech-to-text:
///   1. [initialize] — load model (once, ~1-3s)
///   2. [transcribe] — single-shot transcription
///   3. [startStream] / [pushAudio] / [stopStream] — real-time
///
/// All inference runs on a background [Isolate] to keep
/// the UI thread responsive.
class WhisperSttService {
  WhisperSttService();

  /// Current model status.
  WhisperModelStatus get status => _status;
  WhisperModelStatus _status = WhisperModelStatus.unloaded;

  /// Current language setting.
  String get language => _language;
  String _language = 'auto';

  /// Whether the service is currently streaming.
  bool get isStreaming => _isStreaming;
  bool _isStreaming = false;

  // Isolate communication
  SendPort? _isolateSendPort;
  Isolate? _isolate;
  final StreamController<WhisperTranscript> _transcriptController =
      StreamController<WhisperTranscript>.broadcast();

  /// Stream of transcription results.
  Stream<WhisperTranscript> get transcripts => _transcriptController.stream;

  /// Initialize the Whisper model.
  ///
  /// [modelPath] should be the full path to a ggml model file.
  /// [language] sets the transcription language ("es", "pt", "en", "auto").
  /// [nThreads] sets the number of inference threads (default: 4).
  Future<void> initialize({
    required String modelPath,
    String language = 'auto',
    int nThreads = 4,
  }) async {
    if (_status == WhisperModelStatus.loaded) {
      await dispose();
    }

    _status = WhisperModelStatus.loading;
    _language = language;

    try {
      // Spawn inference isolate
      final Completer<SendPort> portCompleter = Completer<SendPort>();
      final ReceivePort receivePort = ReceivePort();

      _isolate = await Isolate.spawn(
        _inferenceIsolateEntryPoint,
        receivePort.sendPort,
      );

      receivePort.listen((Object? message) {
        if (message is SendPort) {
          portCompleter.complete(message);
        } else if (message is Map<String, Object?>) {
          _handleIsolateMessage(message);
        }
      });

      _isolateSendPort = await portCompleter.future;

      // Send init command
      final Completer<bool> initCompleter = Completer<bool>();

      // Listen for init result
      late final StreamSubscription<WhisperTranscript> sub;
      sub = transcripts.listen((WhisperTranscript t) {
        if (t.type == TranscriptType.status) {
          if (t.text == 'initialized') {
            initCompleter.complete(true);
          } else if (t.text.startsWith('error:')) {
            initCompleter.completeError(WhisperSttException(t.text));
          }
          sub.cancel();
        }
      });

      _isolateSendPort!.send(<String, Object?>{
        'command': 'init',
        'modelPath': modelPath,
        'language': language,
        'nThreads': nThreads,
      });

      await initCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw const WhisperSttException('Model load timeout (30s)'),
      );

      _status = WhisperModelStatus.loaded;
      debugPrint('[WhisperSTT] Model loaded: $modelPath (lang=$language)');
    } catch (e) {
      _status = WhisperModelStatus.error;
      debugPrint('[WhisperSTT] Init failed: $e');
      rethrow;
    }
  }

  /// Transcribe a buffer of PCM int16 audio (single-shot).
  ///
  /// Audio should be mono 16kHz. Returns the transcribed text.
  Future<WhisperTranscript> transcribe(Int16List pcm16Audio) async {
    if (_status != WhisperModelStatus.loaded || _isolateSendPort == null) {
      throw const WhisperSttException('Model not loaded');
    }

    final Completer<WhisperTranscript> completer =
        Completer<WhisperTranscript>();

    late final StreamSubscription<WhisperTranscript> sub;
    sub = transcripts.listen((WhisperTranscript t) {
      if (t.type == TranscriptType.finalResult) {
        completer.complete(t);
        sub.cancel();
      }
    });

    _isolateSendPort!.send(<String, Object?>{
      'command': 'transcribe',
      'audio': pcm16Audio,
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const WhisperSttException('Transcription timeout'),
    );
  }

  /// Push PCM int16 audio for streaming transcription.
  ///
  /// Call [startStream] first. Results arrive via [transcripts] stream.
  void pushAudio(Int16List pcm16Audio) {
    if (!_isStreaming || _isolateSendPort == null) return;

    _isolateSendPort!.send(<String, Object?>{
      'command': 'push_audio',
      'audio': pcm16Audio,
    });
  }

  /// Start streaming mode.
  void startStream() {
    if (_status != WhisperModelStatus.loaded || _isolateSendPort == null) {
      return;
    }

    _isStreaming = true;
    _isolateSendPort!.send(<String, Object?>{'command': 'stream_start'});
    debugPrint('[WhisperSTT] Streaming started');
  }

  /// Stop streaming mode and get final result.
  void stopStream() {
    if (!_isStreaming || _isolateSendPort == null) return;

    _isStreaming = false;
    _isolateSendPort!.send(<String, Object?>{'command': 'stream_stop'});
    debugPrint('[WhisperSTT] Streaming stopped');
  }

  /// Set the transcription language.
  void setLanguage(String lang) {
    _language = lang;
    _isolateSendPort?.send(<String, Object?>{
      'command': 'set_language',
      'language': lang,
    });
  }

  /// Dispose the service and release native resources.
  Future<void> dispose() async {
    _isStreaming = false;
    _isolateSendPort?.send(<String, Object?>{'command': 'dispose'});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolateSendPort = null;
    _status = WhisperModelStatus.unloaded;
    await _transcriptController.close();
    debugPrint('[WhisperSTT] Disposed');
  }

  void _handleIsolateMessage(Map<String, Object?> message) {
    final String? type = message['type'] as String?;

    switch (type) {
      case 'status':
        _transcriptController.add(
          WhisperTranscript(
            text: message['text'] as String? ?? '',
            type: TranscriptType.status,
            durationMs: 0,
            langId: -1,
          ),
        );
      case 'partial':
        _transcriptController.add(
          WhisperTranscript(
            text: message['text'] as String? ?? '',
            type: TranscriptType.partial,
            durationMs: message['duration_ms'] as int? ?? 0,
            langId: message['lang_id'] as int? ?? -1,
          ),
        );
      case 'final':
        _transcriptController.add(
          WhisperTranscript(
            text: message['text'] as String? ?? '',
            type: TranscriptType.finalResult,
            durationMs: message['duration_ms'] as int? ?? 0,
            langId: message['lang_id'] as int? ?? -1,
          ),
        );
    }
  }
}

/// Entry point for the inference isolate.
///
/// This runs whisper inference in a separate isolate to avoid
/// blocking the Flutter UI thread.
void _inferenceIsolateEntryPoint(SendPort mainSendPort) {
  final ReceivePort receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  WhisperBindings? bindings;
  Pointer<WhisperBridgeContext>? ctx;

  receivePort.listen((Object? message) {
    if (message is! Map<String, Object?>) return;
    final String command = message['command'] as String? ?? '';

    switch (command) {
      case 'init':
        try {
          bindings = WhisperBindings();
          final String modelPath = message['modelPath'] as String? ?? '';
          final String language = message['language'] as String? ?? 'auto';
          final int nThreads = message['nThreads'] as int? ?? 4;

          ctx = bindings!.init(modelPath);

          if (ctx == null || ctx == nullptr) {
            mainSendPort.send(<String, String>{
              'type': 'status',
              'text': 'error: failed to load model',
            });
            return;
          }

          bindings!.setLanguage(ctx!, language);
          bindings!.setThreads(ctx!, nThreads);

          mainSendPort.send(<String, String>{
            'type': 'status',
            'text': 'initialized',
          });
        } catch (e) {
          mainSendPort.send(<String, String>{
            'type': 'status',
            'text': 'error: $e',
          });
        }

      case 'transcribe':
        if (bindings == null || ctx == null) return;
        final Int16List audio = message['audio'] as Int16List;
        final Float32List f32 = bindings!.pcm16ToFloat32(audio);
        final WhisperResult result = bindings!.transcribe(ctx!, f32);
        mainSendPort.send(<String, Object>{
          'type': 'final',
          'text': result.text,
          'duration_ms': result.durationMs,
          'lang_id': result.langId,
        });

      case 'push_audio':
        // For streaming: accumulate and transcribe
        if (bindings == null || ctx == null) return;
        final Int16List audio = message['audio'] as Int16List;
        final Float32List f32 = bindings!.pcm16ToFloat32(audio);
        final WhisperResult result = bindings!.transcribe(ctx!, f32);
        mainSendPort.send(<String, Object>{
          'type': 'partial',
          'text': result.text,
          'duration_ms': result.durationMs,
          'lang_id': result.langId,
        });

      case 'set_language':
        if (bindings != null && ctx != null) {
          bindings!.setLanguage(ctx!, message['language'] as String? ?? 'auto');
        }

      case 'dispose':
        if (bindings != null && ctx != null) {
          bindings!.free(ctx!);
          ctx = null;
        }
        Isolate.exit();
    }
  });
}

/// Transcription result from Whisper.
class WhisperTranscript {
  /// Create a WhisperTranscript.
  const WhisperTranscript({
    required this.text,
    required this.type,
    required this.durationMs,
    required this.langId,
  });

  /// Transcribed text.
  final String text;

  /// Result type (partial, final, status).
  final TranscriptType type;

  /// Inference duration in ms.
  final int durationMs;

  /// Detected language ID.
  final int langId;
}

/// Type of transcript result.
enum TranscriptType {
  /// Partial result (may change).
  partial,

  /// Final committed result.
  finalResult,

  /// Status message (init, error).
  status,
}

/// Model loading status.
enum WhisperModelStatus {
  /// No model loaded.
  unloaded,

  /// Model is being loaded.
  loading,

  /// Model loaded and ready.
  loaded,

  /// Error loading model.
  error,
}

/// Exception thrown by WhisperSttService.
class WhisperSttException implements Exception {
  /// Create a WhisperSttException with a message.
  const WhisperSttException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'WhisperSttException: $message';
}
