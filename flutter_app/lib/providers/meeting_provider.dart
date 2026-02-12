import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/services/audio_service.dart';
import 'package:meetmind/services/model_manager.dart';
import 'package:meetmind/services/permission_service.dart';
import 'package:meetmind/services/websocket_service.dart';
import 'package:meetmind/services/whisper_stt_service.dart';
import 'package:uuid/uuid.dart';

/// Provider for the WebSocket service (singleton).
final Provider<WebSocketService> webSocketProvider = Provider<WebSocketService>(
  (Ref ref) {
    final WebSocketService service = WebSocketService();
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Provider for the audio service (singleton).
final Provider<AudioService> audioProvider = Provider<AudioService>((Ref ref) {
  final AudioService service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for the Whisper STT service (singleton).
final Provider<WhisperSttService> whisperProvider = Provider<WhisperSttService>(
  (Ref ref) {
    final WhisperSttService service = WhisperSttService();
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Provider for the model manager.
final Provider<ModelManager> modelManagerProvider = Provider<ModelManager>(
  (Ref ref) => ModelManager(),
);

/// Provider for the permission service.
final Provider<PermissionService> permissionProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

/// Provider for STT model status.
final StateProvider<WhisperModelStatus> sttStatusProvider =
    StateProvider<WhisperModelStatus>((Ref ref) => WhisperModelStatus.unloaded);

/// Provider for the current meeting session.
final StateNotifierProvider<MeetingNotifier, MeetingSession?> meetingProvider =
    StateNotifierProvider<MeetingNotifier, MeetingSession?>((Ref ref) {
      return MeetingNotifier(ref);
    });

/// Provider for connection status.
final StateProvider<ConnectionStatus> connectionStatusProvider =
    StateProvider<ConnectionStatus>((Ref ref) {
      return ConnectionStatus.disconnected;
    });

/// Provider for whether AI agents are available on the backend.
final StateProvider<bool> agentsReadyProvider = StateProvider<bool>((Ref ref) {
  return false;
});

/// Meeting session state manager.
class MeetingNotifier extends StateNotifier<MeetingSession?> {
  MeetingNotifier(this._ref) : super(null);

  final Ref _ref;
  StreamSubscription<Map<String, Object?>>? _messageSub;
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<WhisperTranscript>? _sttSub;
  Timer? _durationTimer;

  // Audio accumulation buffer for STT
  final List<int> _audioBuffer = [];
  static const int _sttChunkSamples = 32000; // 2s at 16kHz

  /// Start a new meeting session.
  Future<void> startMeeting({String title = 'New Meeting'}) async {
    // Check microphone permission first
    final PermissionService permissions = _ref.read(permissionProvider);
    final PermissionResult permResult = await permissions
        .requestMicPermission();

    if (permResult != PermissionResult.granted) {
      debugPrint('[MeetingNotifier] Mic permission: ${permResult.name}');
      throw MeetingException('Microphone permission ${permResult.name}');
    }

    final WebSocketService ws = _ref.read(webSocketProvider);

    // Connect to backend
    _ref.read(connectionStatusProvider.notifier).state =
        ConnectionStatus.connecting;

    try {
      await ws.connect();
      _ref.read(connectionStatusProvider.notifier).state =
          ConnectionStatus.connected;
    } catch (e) {
      _ref.read(connectionStatusProvider.notifier).state =
          ConnectionStatus.error;
      rethrow;
    }

    // Create session
    const Uuid uuid = Uuid();
    state = MeetingSession(
      id: uuid.v4(),
      title: title,
      startTime: DateTime.now(),
      status: MeetingStatus.recording,
    );

    // Listen for backend messages
    _messageSub = ws.messages.listen(_handleMessage);

    // Start audio capture
    await _startAudioCapture();

    // Listen for STT transcripts
    _listenToStt();

    // Start duration timer for UI updates
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state != null) {
        state = state!.copyWith(); // Trigger rebuild for duration
      }
    });
  }

  /// Stop the current meeting.
  Future<void> stopMeeting() async {
    if (state == null) return;

    _durationTimer?.cancel();
    _messageSub?.cancel();
    _sttSub?.cancel();
    await _stopAudioCapture();

    final WebSocketService ws = _ref.read(webSocketProvider);
    await ws.disconnect();

    _ref.read(connectionStatusProvider.notifier).state =
        ConnectionStatus.disconnected;

    state = state!.copyWith(
      status: MeetingStatus.stopped,
      endTime: DateTime.now(),
    );
  }

  /// Pause recording.
  Future<void> pauseMeeting() async {
    if (state == null) return;

    final AudioService audio = _ref.read(audioProvider);
    await audio.pauseRecording();

    state = state!.copyWith(status: MeetingStatus.paused);
  }

  /// Resume recording.
  Future<void> resumeMeeting() async {
    if (state == null) return;

    final AudioService audio = _ref.read(audioProvider);
    await audio.resumeRecording();

    state = state!.copyWith(status: MeetingStatus.recording);
  }

  /// Send a transcript chunk to the backend.
  void addTranscript(String text, {String speaker = 'user'}) {
    final WebSocketService ws = _ref.read(webSocketProvider);
    ws.sendTranscript(text, speaker: speaker);

    // Also add locally for immediate UI feedback
    if (state != null) {
      final TranscriptSegment segment = TranscriptSegment(
        text: text,
        speaker: speaker,
        timestamp: DateTime.now(),
      );
      state = state!.copyWith(segments: [...state!.segments, segment]);
    }
  }

  /// Handle incoming WebSocket messages.
  void _handleMessage(Map<String, Object?> message) {
    final String? type = message['type'] as String?;

    switch (type) {
      case 'connected':
        final bool agentsReady = message['agents_ready'] as bool? ?? false;
        _ref.read(agentsReadyProvider.notifier).state = agentsReady;
        debugPrint('[MeetingNotifier] Connected, agents=$agentsReady');

      case 'transcript_ack':
        debugPrint(
          '[MeetingNotifier] Ack: '
          'segments=${message['segments']}, '
          'buffer=${message['buffer_size']}',
        );

      case 'screening':
        _handleScreening(message);

      case 'analysis':
        _handleAnalysis(message);

      case 'screening_pending':
        if (state != null) {
          state = state!.copyWith(isScreening: true);
        }

      case 'pong':
        break;
    }
  }

  /// Handle a screening result from the backend.
  void _handleScreening(Map<String, Object?> message) {
    if (state == null) return;

    final ScreeningResult result = ScreeningResult.fromJson(message);
    debugPrint(
      '[MeetingNotifier] Screening: '
      'relevant=${result.isRelevant}, '
      'reason=${result.reason}',
    );

    state = state!.copyWith(isScreening: false, lastScreeningResult: result);
  }

  /// Handle an analysis insight from the backend.
  void _handleAnalysis(Map<String, Object?> message) {
    if (state == null) return;

    final Map<String, Object?>? insightData =
        message['insight'] as Map<String, Object?>?;
    if (insightData == null) return;

    final AIInsight insight = AIInsight.fromJson(insightData);
    debugPrint(
      '[MeetingNotifier] Insight: ${insight.categoryEmoji} '
      '${insight.title}',
    );

    state = state!.copyWith(insights: [...state!.insights, insight]);
  }

  /// Start audio capture and pipe to Whisper STT.
  Future<void> _startAudioCapture() async {
    try {
      final AudioService audio = _ref.read(audioProvider);
      final Stream<List<int>> audioStream = await audio.startRecording();

      _audioBuffer.clear();

      _audioSub = audioStream.listen(
        (List<int> data) {
          _audioBuffer.addAll(data);

          // When we have enough audio (~2s), send to STT
          if (_audioBuffer.length >= _sttChunkSamples * 2) {
            // PCM16 = 2 bytes per sample
            _processAudioChunk();
          }
        },
        onError: (Object error) {
          debugPrint('[MeetingNotifier] Audio error: $error');
        },
      );
    } catch (e) {
      debugPrint('[MeetingNotifier] Audio capture failed: $e');
      // Meeting continues without audio — user can still type
    }
  }

  /// Process accumulated audio through Whisper STT.
  void _processAudioChunk() {
    if (_audioBuffer.isEmpty) return;

    final WhisperSttService stt = _ref.read(whisperProvider);
    if (stt.status != WhisperModelStatus.loaded) {
      _audioBuffer.clear();
      return;
    }

    // Convert byte buffer to Int16List
    final Uint8List bytes = Uint8List.fromList(_audioBuffer);
    final Int16List pcm16 = bytes.buffer.asInt16List();
    _audioBuffer.clear();

    // Send to Whisper (runs in isolate, non-blocking)
    stt.pushAudio(pcm16);
  }

  /// Listen to STT transcript stream.
  void _listenToStt() {
    final WhisperSttService stt = _ref.read(whisperProvider);
    if (stt.status != WhisperModelStatus.loaded) return;

    stt.startStream();

    _sttSub = stt.transcripts.listen((WhisperTranscript transcript) {
      if (transcript.type == TranscriptType.partial) {
        // Update partial text in UI (live preview)
        if (state != null) {
          state = state!.copyWith(partialTranscript: transcript.text.trim());
        }
      } else if (transcript.type == TranscriptType.finalResult) {
        final String text = transcript.text.trim();
        if (text.isNotEmpty) {
          // Send finalized text to backend
          addTranscript(text, speaker: 'stt');
          // Clear partial
          if (state != null) {
            state = state!.copyWith(partialTranscript: '');
          }
        }
      }
    });
  }

  /// Stop audio capture.
  Future<void> _stopAudioCapture() async {
    _audioSub?.cancel();
    _audioSub = null;
    _audioBuffer.clear();

    final AudioService audio = _ref.read(audioProvider);
    await audio.stopRecording();

    // Stop STT streaming
    final WhisperSttService stt = _ref.read(whisperProvider);
    if (stt.isStreaming) {
      stt.stopStream();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _messageSub?.cancel();
    _audioSub?.cancel();
    _sttSub?.cancel();
    super.dispose();
  }
}

/// Exception thrown during meeting operations.
class MeetingException implements Exception {
  /// Create a MeetingException with a message.
  const MeetingException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'MeetingException: $message';
}
