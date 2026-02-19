import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/services/meeting_api_service.dart';
import 'package:meetmind/services/notification_service.dart';
import 'package:meetmind/services/permission_service.dart';
import 'package:meetmind/services/stt_service.dart';
import 'package:meetmind/services/subscription_service.dart';
import 'package:meetmind/services/user_preferences.dart';
import 'package:uuid/uuid.dart';

/// Provider for the meeting REST API service (singleton).
final Provider<MeetingApiService> meetingApiProvider =
    Provider<MeetingApiService>((Ref ref) {
  final MeetingApiService service = MeetingApiService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for the STT service (singleton — Apple native speech).
final Provider<SttService> sttProvider = Provider<SttService>(
  (Ref ref) => SttService.instance,
);

/// Provider for the permission service.
final Provider<PermissionService> permissionProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

/// Provider for STT status.
final StateProvider<SttModelStatus> sttStatusProvider =
    StateProvider<SttModelStatus>((Ref ref) => SttModelStatus.unloaded);

/// Provider for the current meeting session.
final StateNotifierProvider<MeetingNotifier, MeetingSession?> meetingProvider =
    StateNotifierProvider<MeetingNotifier, MeetingSession?>((Ref ref) {
  return MeetingNotifier(ref);
});

/// Meeting session state manager — Apple STT + REST API.
///
/// Speech is transcribed on-device by Apple's native SFSpeechRecognizer.
/// Transcript text is sent to the backend REST API for AI features.
class MeetingNotifier extends StateNotifier<MeetingSession?> {
  MeetingNotifier(this._ref) : super(null);

  final Ref _ref;
  StreamSubscription<SttTranscript>? _sttSub;
  Timer? _durationTimer;
  Timer? _transcriptBatchTimer;
  Timer? _partialClearTimer;

  // Buffer transcript segments for batched REST calls
  final List<Map<String, String>> _pendingSegments = [];

  /// Start a new meeting session.
  Future<void> startMeeting({String title = 'New Meeting'}) async {
    // Check microphone permission first
    final PermissionService permissions = _ref.read(permissionProvider);
    final PermissionResult permResult =
        await permissions.requestMicPermission();

    if (permResult != PermissionResult.granted) {
      debugPrint('[MeetingNotifier] Mic permission: ${permResult.name}');
      throw MeetingException('Microphone permission ${permResult.name}');
    }

    // Create session
    const Uuid uuid = Uuid();
    state = MeetingSession(
      id: uuid.v4(),
      title: title,
      startTime: DateTime.now(),
      status: MeetingStatus.recording,
    );

    // Start Apple STT — initialize if needed, then listen
    final SttService stt = _ref.read(sttProvider);
    if (stt.status == SttModelStatus.unloaded) {
      final String lang = UserPreferences.instance.transcriptionLanguage.code;
      await stt.initialize(language: lang == 'auto' ? 'es' : lang);
    }

    if (stt.status == SttModelStatus.ready) {
      _ref.read(sttStatusProvider.notifier).state = SttModelStatus.ready;
      _listenToStt();
    } else {
      debugPrint(
        '[MeetingNotifier] STT not available — user can type manually.',
      );
    }

    // Batch transcript segments every 5s for REST API
    _transcriptBatchTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _flushTranscripts(),
    );

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
    _transcriptBatchTimer?.cancel();
    _sttSub?.cancel();

    // Stop STT
    final SttService stt = _ref.read(sttProvider);
    if (stt.isListening) {
      stt.stopStream();
    }

    // Flush remaining transcripts
    await _flushTranscripts();

    final DateTime endTime = DateTime.now();
    final int durationSecs = endTime.difference(state!.startTime).inSeconds;

    // Persist meeting end to backend
    try {
      final MeetingApiService api = _ref.read(meetingApiProvider);
      await api.endMeeting(
        meetingId: state!.id,
        title: state!.title,
        durationSecs: durationSecs,
      );
      debugPrint('[MeetingNotifier] Meeting ended on backend');
    } catch (e) {
      debugPrint('[MeetingNotifier] End meeting API failed: $e');
      // Non-critical — local state still updates
    }

    state = state!.copyWith(
      status: MeetingStatus.stopped,
      endTime: endTime,
    );

    // Track meeting usage for free-tier limits
    try {
      await SubscriptionService.instance.recordMeetingUsage();
    } catch (_) {
      // Non-critical — don't block meeting end
    }

    // Clear session so next visit creates a fresh meeting
    _flushFailures = 0;
    _partialClearTimer?.cancel();
    state = null;
  }

  /// Pause recording.
  Future<void> pauseMeeting() async {
    if (state == null) return;

    // Pause STT (Apple plugin handles mic directly)
    final SttService stt = _ref.read(sttProvider);
    if (stt.isListening) {
      stt.stopStream();
    }

    state = state!.copyWith(status: MeetingStatus.paused);
  }

  /// Resume recording.
  Future<void> resumeMeeting() async {
    if (state == null) return;

    // Resume STT
    final SttService stt = _ref.read(sttProvider);
    if (stt.status == SttModelStatus.ready) {
      stt.startStream();
    }

    state = state!.copyWith(status: MeetingStatus.recording);
  }

  /// Add a transcript segment locally and queue for backend.
  void addTranscript(String text, {String speaker = 'user'}) {
    if (state == null || text.trim().isEmpty) return;

    // Add locally for immediate UI feedback
    final TranscriptSegment segment = TranscriptSegment(
      text: text,
      speaker: speaker,
      timestamp: DateTime.now(),
    );
    state = state!.copyWith(segments: [...state!.segments, segment]);

    // Queue for batched REST call
    _pendingSegments.add(<String, String>{
      'text': text,
      'speaker': speaker,
    });
  }

  /// Flush pending transcript segments to backend via REST.
  ///
  /// Resilient to backend outages:
  /// - Re-queues on transient errors (network, 500) up to 3 times
  /// - Drops segments on permanent errors (401, 403, 404)
  /// - Prevents infinite log spam from backend issues
  int _flushFailures = 0;
  static const int _maxFlushRetries = 3;

  Future<void> _flushTranscripts() async {
    if (_pendingSegments.isEmpty || state == null) return;

    // If we've failed too many times in a row, drop the queue
    if (_flushFailures >= _maxFlushRetries) {
      final int dropped = _pendingSegments.length;
      _pendingSegments.clear();
      _flushFailures = 0;
      debugPrint(
        '[MeetingNotifier] Dropped $dropped segments after '
        '$_maxFlushRetries consecutive failures — backend unreachable',
      );
      return;
    }

    final List<Map<String, String>> batch = List<Map<String, String>>.from(
      _pendingSegments,
    );
    _pendingSegments.clear();

    try {
      final MeetingApiService api = _ref.read(meetingApiProvider);
      final String langCode =
          UserPreferences.instance.transcriptionLanguage.code;
      final Map<String, dynamic> result = await api.sendTranscript(
        meetingId: state!.id,
        segments: batch,
        language: langCode,
      );

      // Success — reset failure counter
      _flushFailures = 0;

      // Process screening results if returned
      final Map<String, dynamic>? screening =
          result['screening'] as Map<String, dynamic>?;
      if (screening != null) {
        _handleScreeningResult(screening);
      }
    } on ApiException catch (e) {
      // Permanent errors: don't re-queue, just drop
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        _flushFailures++;
        debugPrint(
          '[MeetingNotifier] Transcript flush ${e.statusCode} '
          '(failure $_flushFailures/$_maxFlushRetries) — '
          '${_flushFailures >= _maxFlushRetries ? "will drop queue" : "will retry"}',
        );
        // Re-queue for retry if under limit
        if (_flushFailures < _maxFlushRetries) {
          _pendingSegments.insertAll(0, batch);
        }
      } else {
        // Transient errors (500, timeout): re-queue
        _flushFailures++;
        _pendingSegments.insertAll(0, batch);
        debugPrint('[MeetingNotifier] Transcript flush transient error: $e');
      }
    } catch (e) {
      // Network errors etc: re-queue with limit
      _flushFailures++;
      if (_flushFailures < _maxFlushRetries) {
        _pendingSegments.insertAll(0, batch);
      }
      debugPrint('[MeetingNotifier] Transcript flush failed: $e');
    }
  }

  /// Handle screening result from REST response.
  void _handleScreeningResult(Map<String, dynamic> data) {
    if (state == null) return;

    final ScreeningResult result = ScreeningResult.fromJson(
      data.map((String k, dynamic v) => MapEntry(k, v as Object?)),
    );
    state = state!.copyWith(isScreening: false, lastScreeningResult: result);

    // Check for analysis insight
    final Map<String, dynamic>? analysisData =
        data['analysis'] as Map<String, dynamic>?;
    if (analysisData != null) {
      final AIInsight insight = AIInsight.fromJson(
        analysisData.map((String k, dynamic v) => MapEntry(k, v as Object?)),
      );
      state = state!.copyWith(insights: [...state!.insights, insight]);

      // Show push notification if app is in background
      final AppLifecycleState? lifecycle =
          WidgetsBinding.instance.lifecycleState;
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
  }

  /// Send a copilot query to the backend via REST.
  Future<void> sendCopilotQuery(String question) async {
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

    try {
      final MeetingApiService api = _ref.read(meetingApiProvider);
      final String context = state!.segments
          .map((TranscriptSegment s) => '[${s.speaker}] ${s.text}')
          .join('\n');

      final Map<String, dynamic> response = await api.askCopilot(
        meetingId: state!.id,
        question: question,
        transcriptContext: context,
      );

      final String answer = response['answer'] as String? ?? '';
      final bool isError = response['error'] as bool? ?? false;
      final int? latencyMs = response['latency_ms'] as int?;
      final String? modelTier = response['model_tier'] as String?;

      final CopilotMessage aiMsg = CopilotMessage(
        text: answer,
        sender: isError ? CopilotSender.error : CopilotSender.ai,
        timestamp: DateTime.now(),
        latencyMs: latencyMs,
        modelTier: modelTier,
      );

      if (state != null) {
        state = state!.copyWith(
          copilotMessages: [...state!.copilotMessages, aiMsg],
          isCopilotLoading: false,
        );
      }
    } catch (e) {
      debugPrint('[MeetingNotifier] Copilot failed: $e');
      if (state != null) {
        final CopilotMessage errorMsg = CopilotMessage(
          text: 'Connection error. Please try again.',
          sender: CopilotSender.error,
          timestamp: DateTime.now(),
        );
        state = state!.copyWith(
          copilotMessages: [...state!.copilotMessages, errorMsg],
          isCopilotLoading: false,
        );
      }
    }
  }

  /// Request a meeting summary from the backend via REST.
  Future<void> requestSummary() async {
    if (state == null) return;
    state = state!.copyWith(isSummaryLoading: true);

    try {
      final MeetingApiService api = _ref.read(meetingApiProvider);
      final String langCode =
          UserPreferences.instance.transcriptionLanguage.code;
      final String fullTranscript = state!.segments
          .map((TranscriptSegment s) => '[${s.speaker}] ${s.text}')
          .join('\n');

      final Map<String, dynamic> response = await api.generateSummary(
        meetingId: state!.id,
        fullTranscript: fullTranscript,
        language: langCode,
      );

      final bool isError = response['error'] as bool? ?? false;
      final Map<String, dynamic>? summaryData =
          response['summary'] as Map<String, dynamic>?;

      if (isError || summaryData == null) {
        debugPrint('[MeetingNotifier] Summary error');
        if (state != null) {
          state = state!.copyWith(isSummaryLoading: false);
        }
        return;
      }

      final MeetingSummary summary = MeetingSummary.fromJson(
        summaryData.map((String k, dynamic v) => MapEntry(k, v as Object?)),
      );
      if (state != null) {
        state = state!.copyWith(
          meetingSummary: summary,
          isSummaryLoading: false,
        );
      }
    } catch (e) {
      debugPrint('[MeetingNotifier] Summary failed: $e');
      if (state != null) {
        state = state!.copyWith(isSummaryLoading: false);
      }
    }
  }

  /// Listen to Apple STT transcript stream.
  void _listenToStt() {
    final SttService stt = _ref.read(sttProvider);
    stt.startStream();

    _sttSub = stt.transcripts.listen((SttTranscript transcript) {
      if (transcript.type == TranscriptType.partial) {
        // Update partial text in UI (live preview)
        if (state != null) {
          state = state!.copyWith(partialTranscript: transcript.text.trim());
        }
        // Auto-clear partial after 2s of silence (no new partial)
        _partialClearTimer?.cancel();
        _partialClearTimer = Timer(const Duration(seconds: 2), () {
          if (state != null && state!.partialTranscript.isNotEmpty) {
            state = state!.copyWith(partialTranscript: '');
          }
        });
      } else if (transcript.type == TranscriptType.finalResult) {
        _partialClearTimer?.cancel();
        final String text = transcript.text.trim();
        if (text.isNotEmpty) {
          // Add finalized text to transcript + queue for backend
          addTranscript(text, speaker: 'stt');
          // Clear partial
          if (state != null) {
            state = state!.copyWith(partialTranscript: '');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _transcriptBatchTimer?.cancel();
    _partialClearTimer?.cancel();
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
