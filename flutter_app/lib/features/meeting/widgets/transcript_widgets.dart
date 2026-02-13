import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';

/// Status bar with recording state, segment count, and AI indicator.
class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.status,
    required this.segmentCount,
    required this.isScreening,
    required this.insightCount,
    super.key,
  });

  final MeetingStatus status;
  final int segmentCount;
  final bool isScreening;
  final int insightCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MeetMindTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // Recording indicator
          Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status == MeetingStatus.recording
                      ? MeetMindTheme.error
                      : status == MeetingStatus.paused
                      ? MeetMindTheme.warning
                      : Colors.white38,
                  shape: BoxShape.circle,
                ),
              )
              .animate(
                target: status == MeetingStatus.recording ? 1 : 0,
                onPlay: (AnimationController c) => c.repeat(reverse: true),
              )
              .fadeOut(begin: 1, end: 0.3, duration: 800.ms),
          const SizedBox(width: 8),

          Text(
            status == MeetingStatus.recording
                ? 'Recording'
                : status == MeetingStatus.paused
                ? 'Paused'
                : 'Idle',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),

          const Spacer(),

          // Segment count
          Icon(
            Icons.segment,
            size: 14,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            '$segmentCount',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(width: 16),

          // AI screening status
          if (isScreening)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MeetMindTheme.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MeetMindTheme.accent,
                  ),
                ),
              ],
            )
          else if (insightCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: MeetMindTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 $insightCount',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// Scrollable transcript list.
class TranscriptList extends StatelessWidget {
  const TranscriptList({
    required this.segments,
    required this.scrollController,
    super.key,
  });

  final List<TranscriptSegment> segments;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      itemBuilder: (BuildContext context, int index) {
        return TranscriptBubble(segment: segments[index])
            .animate()
            .fadeIn(duration: 200.ms)
            .slideY(begin: 0.05, duration: 200.ms);
      },
    );
  }
}

/// Individual transcript bubble.
class TranscriptBubble extends StatelessWidget {
  const TranscriptBubble({required this.segment, super.key});

  final TranscriptSegment segment;

  /// Speaker color map.
  static const Map<String, Color> _speakerColors = <String, Color>{
    'Speaker A': Color(0xFF60a5fa),
    'Speaker B': Color(0xFF34d399),
    'Speaker C': Color(0xFFfbbf24),
    'Speaker D': Color(0xFFf87171),
    'Speaker E': Color(0xFFa78bfa),
    'Speaker F': Color(0xFFfb923c),
    'Speaker G': Color(0xFF2dd4bf),
    'Speaker H': Color(0xFFf472b6),
  };

  @override
  Widget build(BuildContext context) {
    final Color speakerColor =
        _speakerColors[segment.speaker] ?? const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MeetMindTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: segment.isRelevant
              ? MeetMindTheme.warning.withValues(alpha: 0.4)
              : MeetMindTheme.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker label + timestamp
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: speakerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                segment.speaker,
                style: TextStyle(
                  color: speakerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${segment.timestamp.hour.toString().padLeft(2, '0')}'
                ':${segment.timestamp.minute.toString().padLeft(2, '0')}'
                ':${segment.timestamp.second.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Transcript text
          Text(
            segment.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty transcript state.
class EmptyTranscriptState extends StatelessWidget {
  const EmptyTranscriptState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 64,
            color: MeetMindTheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for audio...',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            'Speak into your microphone.\n'
            'Transcriptions will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }
}
