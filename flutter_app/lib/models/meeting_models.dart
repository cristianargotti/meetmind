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

/// Sender type for copilot chat messages.
enum CopilotSender { user, ai, error }

/// A single copilot chat message.
class CopilotMessage {
  const CopilotMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.latencyMs,
    this.modelTier,
  });

  final String text;
  final CopilotSender sender;
  final DateTime timestamp;
  final int? latencyMs;
  final String? modelTier;
}

/// Session cost tracking data from the backend.
class CostData {
  const CostData({
    required this.totalCostUsd,
    required this.budgetUsd,
    required this.budgetRemainingUsd,
    required this.budgetPct,
    this.budgetExceeded = false,
  });

  factory CostData.fromJson(Map<String, Object?> json) {
    return CostData(
      totalCostUsd: (json['total_cost_usd'] as num?)?.toDouble() ?? 0,
      budgetUsd: (json['budget_usd'] as num?)?.toDouble() ?? 0.50,
      budgetRemainingUsd:
          (json['budget_remaining_usd'] as num?)?.toDouble() ?? 0.50,
      budgetPct: (json['budget_pct'] as num?)?.toDouble() ?? 0,
    );
  }

  final double totalCostUsd;
  final double budgetUsd;
  final double budgetRemainingUsd;
  final double budgetPct;
  final bool budgetExceeded;

  /// Copy with budget exceeded flag.
  CostData withBudgetExceeded() {
    return CostData(
      totalCostUsd: totalCostUsd,
      budgetUsd: budgetUsd,
      budgetRemainingUsd: 0,
      budgetPct: 1.0,
      budgetExceeded: true,
    );
  }
}

/// Structured meeting summary from the backend.
class MeetingSummary {
  const MeetingSummary({
    required this.title,
    required this.summary,
    this.decisions = const [],
    this.actionItems = const [],
    this.keyTopics = const [],
    this.followUps = const [],
    this.latencyMs,
  });

  factory MeetingSummary.fromJson(Map<String, Object?> json) {
    return MeetingSummary(
      title: json['title'] as String? ?? 'Meeting Summary',
      summary: json['summary'] as String? ?? '',
      decisions: _parseStringList(json['decisions']),
      actionItems: _parseStringList(json['action_items']),
      keyTopics: _parseStringList(json['key_topics']),
      followUps: _parseStringList(json['follow_ups']),
      latencyMs: json['latency_ms'] as int?,
    );
  }

  final String title;
  final String summary;
  final List<String> decisions;
  final List<String> actionItems;
  final List<String> keyTopics;
  final List<String> followUps;
  final int? latencyMs;

  /// Convert summary to markdown for clipboard.
  String toMarkdown() {
    final StringBuffer buf = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln(summary)
      ..writeln();

    if (decisions.isNotEmpty) {
      buf.writeln('## 📌 Decisions');
      for (final String d in decisions) {
        buf.writeln('- $d');
      }
      buf.writeln();
    }
    if (actionItems.isNotEmpty) {
      buf.writeln('## ✅ Action Items');
      for (final String a in actionItems) {
        buf.writeln('- $a');
      }
      buf.writeln();
    }
    if (keyTopics.isNotEmpty) {
      buf.writeln('## 💬 Key Topics');
      for (final String t in keyTopics) {
        buf.writeln('- $t');
      }
      buf.writeln();
    }
    if (followUps.isNotEmpty) {
      buf.writeln('## 📅 Follow-Ups');
      for (final String f in followUps) {
        buf.writeln('- $f');
      }
    }
    return buf.toString();
  }

  static List<String> _parseStringList(Object? value) {
    if (value is List) {
      return value.map((Object? e) => e.toString()).toList();
    }
    return <String>[];
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
    this.copilotMessages = const [],
    this.status = MeetingStatus.idle,
    this.isScreening = false,
    this.lastScreeningResult,
    this.partialTranscript = '',
    this.costData,
    this.meetingSummary,
    this.isCopilotLoading = false,
    this.isSummaryLoading = false,
  });

  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final List<TranscriptSegment> segments;
  final List<AIInsight> insights;
  final List<CopilotMessage> copilotMessages;
  final MeetingStatus status;
  final bool isScreening;
  final ScreeningResult? lastScreeningResult;
  final CostData? costData;
  final MeetingSummary? meetingSummary;
  final bool isCopilotLoading;
  final bool isSummaryLoading;

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
    List<CopilotMessage>? copilotMessages,
    MeetingStatus? status,
    bool? isScreening,
    ScreeningResult? lastScreeningResult,
    String? partialTranscript,
    CostData? costData,
    MeetingSummary? meetingSummary,
    bool? isCopilotLoading,
    bool? isSummaryLoading,
  }) {
    return MeetingSession(
      id: id,
      title: title ?? this.title,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      segments: segments ?? this.segments,
      insights: insights ?? this.insights,
      copilotMessages: copilotMessages ?? this.copilotMessages,
      status: status ?? this.status,
      isScreening: isScreening ?? this.isScreening,
      lastScreeningResult: lastScreeningResult ?? this.lastScreeningResult,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      costData: costData ?? this.costData,
      meetingSummary: meetingSummary ?? this.meetingSummary,
      isCopilotLoading: isCopilotLoading ?? this.isCopilotLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
    );
  }
}
