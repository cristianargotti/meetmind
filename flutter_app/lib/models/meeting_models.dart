/// WebSocket connection status.
enum ConnectionStatus { disconnected, connecting, connected, error }

/// Meeting session state.
enum MeetingStatus { idle, recording, paused, stopped }

/// A single transcript segment from the backend.
class TranscriptSegment {
  const TranscriptSegment({
    required this.text,
    required this.speaker,
    required this.timestamp,
    this.isRelevant = false,
  });

  factory TranscriptSegment.fromJson(Map<String, Object?> json) {
    return TranscriptSegment(
      text: json['text'] as String? ?? '',
      speaker: json['speaker'] as String? ?? 'unknown',
      timestamp: DateTime.now(),
      isRelevant: json['relevant'] as bool? ?? false,
    );
  }

  final String text;
  final String speaker;
  final DateTime timestamp;
  final bool isRelevant;
}

/// AI screening result from the backend.
class ScreeningResult {
  const ScreeningResult({
    required this.isRelevant,
    required this.reason,
    required this.textLength,
  });

  factory ScreeningResult.fromJson(Map<String, Object?> json) {
    return ScreeningResult(
      isRelevant: json['relevant'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      textLength: json['text_length'] as int? ?? 0,
    );
  }

  final bool isRelevant;
  final String reason;
  final int textLength;
}

/// AI insight generated from analysis agent.
class AIInsight {
  const AIInsight({
    required this.title,
    required this.analysis,
    required this.recommendation,
    required this.category,
    required this.timestamp,
  });

  factory AIInsight.fromJson(Map<String, Object?> json) {
    return AIInsight(
      title: json['title'] as String? ?? 'Insight',
      analysis: json['analysis'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
      category: json['category'] as String? ?? 'idea',
      timestamp: DateTime.now(),
    );
  }

  final String title;
  final String analysis;
  final String recommendation;
  final String category;
  final DateTime timestamp;

  /// Icon for the insight category.
  String get categoryEmoji {
    switch (category) {
      case 'decision':
        return '📌';
      case 'action':
        return '✅';
      case 'risk':
        return '⚠️';
      case 'idea':
        return '💡';
      default:
        return '💬';
    }
  }
}

/// Meeting session data.
class MeetingSession {
  const MeetingSession({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.segments = const [],
    this.insights = const [],
    this.status = MeetingStatus.idle,
    this.isScreening = false,
    this.lastScreeningResult,
    this.partialTranscript = '',
  });

  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final List<TranscriptSegment> segments;
  final List<AIInsight> insights;
  final MeetingStatus status;
  final bool isScreening;
  final ScreeningResult? lastScreeningResult;

  /// Live partial text from on-device STT (updates in real-time).
  final String partialTranscript;

  Duration get duration {
    final DateTime end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  MeetingSession copyWith({
    String? title,
    DateTime? endTime,
    List<TranscriptSegment>? segments,
    List<AIInsight>? insights,
    MeetingStatus? status,
    bool? isScreening,
    ScreeningResult? lastScreeningResult,
    String? partialTranscript,
  }) {
    return MeetingSession(
      id: id,
      title: title ?? this.title,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      segments: segments ?? this.segments,
      insights: insights ?? this.insights,
      status: status ?? this.status,
      isScreening: isScreening ?? this.isScreening,
      lastScreeningResult: lastScreeningResult ?? this.lastScreeningResult,
      partialTranscript: partialTranscript ?? this.partialTranscript,
    );
  }
}
