import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/features/meeting/widgets/input_bar.dart';
import 'package:meetmind/features/meeting/widgets/insight_widgets.dart';
import 'package:meetmind/features/meeting/widgets/stt_widgets.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/services/whisper_stt_service.dart';

/// Active meeting screen — real-time transcription + AI insights.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({super.key});

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final MeetingSession? meeting = ref.read(meetingProvider);
      if (meeting == null) {
        final String minute = DateTime.now().minute.toString().padLeft(2, '0');
        ref
            .read(meetingProvider.notifier)
            .startMeeting(title: 'Meeting ${DateTime.now().hour}:$minute');
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MeetingSession? meeting = ref.watch(meetingProvider);
    final ConnectionStatus connectionStatus = ref.watch(
      connectionStatusProvider,
    );
    final WhisperModelStatus sttStatus = ref.watch(sttStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(meeting?.title ?? 'Meeting'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showStopConfirmation(context),
        ),
        actions: [
          SttBadge(status: sttStatus),
          const SizedBox(width: 4),
          _ConnectionBadge(status: connectionStatus),
          const SizedBox(width: 8),
          if (meeting != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _formatDuration(meeting.duration),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _StatusBar(
            status: meeting?.status ?? MeetingStatus.idle,
            segmentCount: meeting?.segments.length ?? 0,
            isScreening: meeting?.isScreening ?? false,
            insightCount: meeting?.insights.length ?? 0,
          ).animate().fadeIn(duration: 300.ms),
          if (meeting != null && meeting.insights.isNotEmpty)
            InsightsPanel(insights: meeting.insights),
          Expanded(
            child: meeting == null || meeting.segments.isEmpty
                ? const _EmptyTranscriptState()
                : _TranscriptList(
                    segments: meeting.segments,
                    scrollController: _scrollController,
                  ),
          ),
          // Live partial transcript from Whisper STT
          if (meeting != null && meeting.partialTranscript.isNotEmpty)
            PartialTranscriptBar(text: meeting.partialTranscript),
          InputBar(
            controller: _textController,
            isRecording: meeting?.status == MeetingStatus.recording,
            onSend: () {
              final String text = _textController.text.trim();
              if (text.isNotEmpty) {
                ref.read(meetingProvider.notifier).addTranscript(text);
                _textController.clear();
                _scrollToBottom();
              }
            },
            onToggleRecording: () {
              if (meeting?.status == MeetingStatus.recording) {
                ref.read(meetingProvider.notifier).pauseMeeting();
              } else {
                ref.read(meetingProvider.notifier).resumeMeeting();
              }
            },
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showStopConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: MeetMindTheme.darkCard,
        title: const Text('End Meeting?'),
        content: const Text(
          'This will stop transcription and save the session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(meetingProvider.notifier).stopMeeting();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final String hours = d.inHours.toString().padLeft(2, '0');
    final String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Connection status badge.
class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (status) {
      case ConnectionStatus.connected:
        color = MeetMindTheme.success;
        label = 'Connected';
      case ConnectionStatus.connecting:
        color = MeetMindTheme.warning;
        label = 'Connecting...';
      case ConnectionStatus.error:
        color = MeetMindTheme.error;
        label = 'Error';
      case ConnectionStatus.disconnected:
        color = Colors.white38;
        label = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status bar with recording state, segment count, and AI indicator.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.status,
    required this.segmentCount,
    required this.isScreening,
    required this.insightCount,
  });

  final MeetingStatus status;
  final int segmentCount;
  final bool isScreening;
  final int insightCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: MeetMindTheme.darkSurface,
      child: Row(
        children: [
          if (status == MeetingStatus.recording) ...[
            const Icon(
                  Icons.fiber_manual_record,
                  color: MeetMindTheme.error,
                  size: 12,
                )
                .animate(onPlay: (AnimationController c) => c.repeat())
                .fadeIn(duration: 800.ms)
                .then()
                .fadeOut(duration: 800.ms),
            const SizedBox(width: 8),
            const Text(
              'Recording',
              style: TextStyle(color: MeetMindTheme.error, fontSize: 13),
            ),
          ] else if (status == MeetingStatus.paused) ...[
            const Icon(Icons.pause, color: MeetMindTheme.warning, size: 14),
            const SizedBox(width: 8),
            const Text(
              'Paused',
              style: TextStyle(color: MeetMindTheme.warning, fontSize: 13),
            ),
          ],
          const Spacer(),
          if (isScreening)
            const Row(
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
                SizedBox(width: 6),
                Text(
                  'AI analyzing...',
                  style: TextStyle(color: MeetMindTheme.accent, fontSize: 11),
                ),
              ],
            ),
          if (insightCount > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MeetMindTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 $insightCount',
                style: const TextStyle(
                  color: MeetMindTheme.accent,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Text(
            '$segmentCount segments',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Empty transcript state.
class _EmptyTranscriptState extends StatelessWidget {
  const _EmptyTranscriptState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
                Icons.graphic_eq,
                size: 48,
                color: MeetMindTheme.primary.withValues(alpha: 0.3),
              )
              .animate(onPlay: (AnimationController c) => c.repeat())
              .scaleXY(begin: 0.9, end: 1.1, duration: 1500.ms)
              .then()
              .scaleXY(begin: 1.1, end: 0.9, duration: 1500.ms),
          const SizedBox(height: 16),
          const Text(
            'Listening...',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type a message or speak to add transcript',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Scrollable transcript list.
class _TranscriptList extends StatelessWidget {
  const _TranscriptList({
    required this.segments,
    required this.scrollController,
  });

  final List<TranscriptSegment> segments;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: segments.length,
      itemBuilder: (BuildContext context, int index) {
        final TranscriptSegment segment = segments[index];
        return _TranscriptBubble(
          segment: segment,
        ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05);
      },
    );
  }
}

/// Individual transcript bubble.
class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.segment});

  final TranscriptSegment segment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: MeetMindTheme.primary.withValues(alpha: 0.2),
            child: Text(
              segment.speaker[0].toUpperCase(),
              style: const TextStyle(
                color: MeetMindTheme.primaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MeetMindTheme.darkCard,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: segment.isRelevant
                    ? Border.all(
                        color: MeetMindTheme.accent.withValues(alpha: 0.4),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.speaker,
                    style: const TextStyle(
                      color: MeetMindTheme.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            ),
          ),
        ],
      ),
    );
  }
}
