import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/config/app_config.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/services/audio_service.dart';
import 'package:meetmind/services/model_manager.dart';
import 'package:meetmind/services/notification_service.dart';
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
  static const int _sttChunkSamples =
      1600; // 100ms at 16kHz (real-time streaming)

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
      await ws.connect(wsUrl: _ref.read(appConfigProvider).wsUrl);
      _ref.read(connectionStatusProvider.notifier).state =
          ConnectionStatus.connected;
      // Server-side STT (Moonshine) — mark STT as ready immediately
      _ref.read(sttStatusProvider.notifier).state = WhisperModelStatus.loaded;
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
        final String? text = message['text'] as String?;
        final bool isPartial = message['partial'] as bool? ?? false;
        final String speaker = message['speaker'] as String? ?? 'unknown';

        if (text != null && text.isNotEmpty && state != null) {
          if (isPartial) {
            // Live preview of partial transcription
            state = state!.copyWith(partialTranscript: text);
          } else {
            // Finalized transcription — add as segment
            final TranscriptSegment segment = TranscriptSegment(
              text: text,
              speaker: speaker,
              timestamp: DateTime.now(),
            );
            state = state!.copyWith(
              segments: [...state!.segments, segment],
              partialTranscript: '',
            );
          }
        }

        debugPrint(
          '[MeetingNotifier] Ack: '
          'text=${text?.substring(0, (text.length > 50 ? 50 : text.length))}, '
          'partial=$isPartial, '
          'speaker=$speaker',
        );

      case 'screening':
        _handleScreening(message);

      case 'analysis':
        _handleAnalysis(message);

      case 'copilot_response':
        _handleCopilotResponse(message);

      case 'meeting_summary':
        _handleMeetingSummary(message);

      case 'cost_update':
        _handleCostUpdate(message);

      case 'budget_exceeded':
        _handleBudgetExceeded();

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

    // Show push notification if app is in background
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      NotificationService.instance.showInsightNotification(
        title: '${insight.categoryEmoji} ${insight.title}',
        body: insight.analysis.isNotEmpty
            ? insight.analysis
            : 'New insight detected in your meeting',
      );
    }
  }

  /// Handle a copilot response from the backend.
  void _handleCopilotResponse(Map<String, Object?> message) {
    if (state == null) return;

    final String answer = message['answer'] as String? ?? '';
    final bool isError = message['error'] as bool? ?? false;
    final int? latencyMs = message['latency_ms'] as int?;
    final String? modelTier = message['model_tier'] as String?;

    final CopilotMessage aiMsg = CopilotMessage(
      text: answer,
      sender: isError ? CopilotSender.error : CopilotSender.ai,
      timestamp: DateTime.now(),
      latencyMs: latencyMs,
      modelTier: modelTier,
    );

    state = state!.copyWith(
      copilotMessages: [...state!.copilotMessages, aiMsg],
      isCopilotLoading: false,
    );
  }

  /// Handle meeting summary from the backend.
  void _handleMeetingSummary(Map<String, Object?> message) {
    if (state == null) return;

    final bool isError = message['error'] as bool? ?? false;
    final Map<String, Object?>? summaryData =
        message['summary'] as Map<String, Object?>?;

    if (isError || summaryData == null) {
      debugPrint('[MeetingNotifier] Summary error');
      state = state!.copyWith(isSummaryLoading: false);
      return;
    }

    final MeetingSummary summary = MeetingSummary.fromJson(summaryData);
    debugPrint('[MeetingNotifier] Summary: ${summary.title}');

    state = state!.copyWith(meetingSummary: summary, isSummaryLoading: false);
  }

  /// Handle cost update from the backend.
  void _handleCostUpdate(Map<String, Object?> message) {
    if (state == null) return;
    state = state!.copyWith(costData: CostData.fromJson(message));
  }

  /// Handle budget exceeded notification.
  void _handleBudgetExceeded() {
    if (state == null) return;
    final CostData current =
        state!.costData ??
        const CostData(
          totalCostUsd: 0,
          budgetUsd: 0.50,
          budgetRemainingUsd: 0,
          budgetPct: 1.0,
        );
    state = state!.copyWith(costData: current.withBudgetExceeded());
  }

  /// Send a copilot query to the backend.
  void sendCopilotQuery(String question) {
    if (state == null || question.trim().isEmpty) return;

    // Add user message to chat
    final CopilotMessage userMsg = CopilotMessage(
      text: question,
      sender: CopilotSender.user,
      timestamp: DateTime.now(),
    );
    state = state!.copyWith(
      copilotMessages: [...state!.copilotMessages, userMsg],
      isCopilotLoading: true,
    );

    // Send via WebSocket
    _ref.read(webSocketProvider).sendCopilotQuery(question);
  }

  /// Request a meeting summary from the backend.
  void requestSummary() {
    if (state == null) return;
    state = state!.copyWith(isSummaryLoading: true);
    _ref.read(webSocketProvider).sendSummaryRequest();
  }

  /// Start audio capture and send to backend via WebSocket.
  Future<void> _startAudioCapture() async {
    try {
      final AudioService audio = _ref.read(audioProvider);
      final Stream<List<int>> audioStream = await audio.startRecording();

      _audioBuffer.clear();

      _audioSub = audioStream.listen(
        (List<int> data) {
          _audioBuffer.addAll(data);

          // Stream audio in small chunks (~100ms) for real-time STT
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

  /// Send accumulated audio to backend via WebSocket.
  void _processAudioChunk() {
    if (_audioBuffer.isEmpty) return;

    final WebSocketService ws = _ref.read(webSocketProvider);
    if (ws.status != ConnectionStatus.connected) {
      _audioBuffer.clear();
      return;
    }

    // Send raw PCM bytes to server for STT (use Uint8List for zero-copy)
    ws.sendAudio(Uint8List.fromList(_audioBuffer));
    _audioBuffer.clear();
  }

  /// Listen to STT transcript stream (no-op when using server-side STT).
  void _listenToStt() {
    // Server-side STT: transcripts arrive via WebSocket messages
    // handled in _handleMessage (transcript_ack with text field).
    // On-device STT would be initialized here if the model was loaded.
    final WhisperSttService stt = _ref.read(whisperProvider);
    if (stt.status != WhisperModelStatus.loaded) {
      debugPrint(
        '[MeetingNotifier] On-device STT not loaded, using server-side STT',
      );
      return;
    }

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
