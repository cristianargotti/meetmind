import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:meetmind/features/meeting/widgets/copilot_panel.dart';
import 'package:meetmind/features/meeting/widgets/input_bar.dart';
import 'package:meetmind/features/meeting/widgets/insight_widgets.dart';
import 'package:meetmind/features/meeting/widgets/stt_widgets.dart';
import 'package:meetmind/features/meeting/widgets/summary_panel.dart';
import 'package:meetmind/features/meeting/widgets/transcript_widgets.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/services/stt_service.dart';

/// Active meeting screen — real-time transcription + AI insights.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({super.key});

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MeetingSession? meeting = ref.watch(meetingProvider);
    final SttModelStatus sttStatus = ref.watch(sttStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(meeting?.title ?? 'Meeting'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showStopConfirmation(context),
        ),
        actions: [
          SttBadge(status: sttStatus),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _MeetingTabBar(controller: _tabController),
        ),
      ),
      body: Column(
        children: <Widget>[
          // Cost bar (shown when AI calls have been made)
          // Cost tracker hidden — Groq free tier ($0/month)

          // Status bar
          StatusBar(
            status: meeting?.status ?? MeetingStatus.idle,
            segmentCount: meeting?.segments.length ?? 0,
            isScreening: meeting?.isScreening ?? false,
            insightCount: meeting?.insights.length ?? 0,
          ).animate().fadeIn(duration: 300.ms),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                // Tab 1: Transcript
                _TranscriptTab(
                  meeting: meeting,
                  scrollController: _scrollController,
                  textController: _textController,
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

                // Tab 2: Insights (proactive AI suggestions)
                InsightsTab(insights: meeting?.insights ?? const []),

                // Tab 3: Copilot
                CopilotPanel(
                  messages: meeting?.copilotMessages ?? const [],
                  isLoading: meeting?.isCopilotLoading ?? false,
                  onSend: (String question) {
                    ref
                        .read(meetingProvider.notifier)
                        .sendCopilotQuery(question);
                  },
                ),

                // Tab 4: Summary
                SummaryPanel(
                  summary: meeting?.meetingSummary,
                  isLoading: meeting?.isSummaryLoading ?? false,
                  hasTranscript: (meeting?.segments.length ?? 0) > 0,
                  onGenerate: () {
                    ref.read(meetingProvider.notifier).requestSummary();
                  },
                ),
              ],
            ),
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
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('End Meeting?'),
        content: const Text('This will stop recording and disconnect.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(meetingProvider.notifier).stopMeeting();
              Navigator.of(dialogContext).pop();
              context.go('/');
            },
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final String h = d.inHours.toString().padLeft(2, '0');
    final String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// Tab bar for meeting screen.
class _MeetingTabBar extends StatelessWidget {
  const _MeetingTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tabs: const <Tab>[
        Tab(icon: Icon(Icons.subtitles_outlined, size: 18), text: 'Transcript'),
        Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Insights'),
        Tab(icon: Icon(Icons.smart_toy_outlined, size: 18), text: 'Copilot'),
        Tab(icon: Icon(Icons.summarize_outlined, size: 18), text: 'Summary'),
      ],
    );
  }
}

/// Transcript tab — insights panel + transcript list + input.
class _TranscriptTab extends StatefulWidget {
  const _TranscriptTab({
    required this.meeting,
    required this.scrollController,
    required this.textController,
    required this.onSend,
    required this.onToggleRecording,
  });

  final MeetingSession? meeting;
  final ScrollController scrollController;
  final TextEditingController textController;
  final VoidCallback onSend;
  final VoidCallback onToggleRecording;

  @override
  State<_TranscriptTab> createState() => _TranscriptTabState();
}

class _TranscriptTabState extends State<_TranscriptTab> {
  int _lastSegmentCount = 0;

  @override
  void didUpdateWidget(covariant _TranscriptTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int newCount = widget.meeting?.segments.length ?? 0;
    if (newCount > _lastSegmentCount) {
      _lastSegmentCount = newCount;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: widget.meeting == null || widget.meeting!.segments.isEmpty
              ? const EmptyTranscriptState()
              : TranscriptList(
                  segments: widget.meeting!.segments,
                  scrollController: widget.scrollController,
                ),
        ),
        // Live partial transcript from STT
        if (widget.meeting != null &&
            widget.meeting!.partialTranscript.isNotEmpty)
          PartialTranscriptBar(text: widget.meeting!.partialTranscript),
        InputBar(
          controller: widget.textController,
          isRecording: widget.meeting?.status == MeetingStatus.recording,
          onSend: widget.onSend,
          onToggleRecording: widget.onToggleRecording,
        ),
      ],
    );
  }
}
