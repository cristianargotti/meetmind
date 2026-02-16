import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/features/meeting/widgets/copilot_panel.dart';
import 'package:meetmind/features/meeting/widgets/cost_bar.dart';
import 'package:meetmind/features/meeting/widgets/input_bar.dart';
import 'package:meetmind/features/meeting/widgets/insight_widgets.dart';
import 'package:meetmind/features/meeting/widgets/stt_widgets.dart';
import 'package:meetmind/features/meeting/widgets/summary_panel.dart';
import 'package:meetmind/features/meeting/widgets/transcript_widgets.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/services/whisper_stt_service.dart';

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _MeetingTabBar(controller: _tabController),
        ),
      ),
      body: Column(
        children: <Widget>[
          // Cost bar (shown when AI calls have been made)
          CostBar(costData: meeting?.costData),

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
              Navigator.of(context).pop();
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
class _TranscriptTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: meeting == null || meeting!.segments.isEmpty
              ? const EmptyTranscriptState()
              : TranscriptList(
                  segments: meeting!.segments,
                  scrollController: scrollController,
                ),
        ),
        // Live partial transcript from STT
        if (meeting != null && meeting!.partialTranscript.isNotEmpty)
          PartialTranscriptBar(text: meeting!.partialTranscript),
        InputBar(
          controller: textController,
          isRecording: meeting?.status == MeetingStatus.recording,
          onSend: onSend,
          onToggleRecording: onToggleRecording,
        ),
      ],
    );
  }
}

/// Connection status badge.
class _ConnectionBadge extends ConsumerWidget {
  const _ConnectionBadge({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color;
    final String label;
    final IconData icon;

    switch (status) {
      case ConnectionStatus.connected:
        color = MeetMindTheme.success;
        label = 'Live';
        icon = Icons.wifi;
      case ConnectionStatus.connecting:
        color = MeetMindTheme.warning;
        label = 'Connecting';
        icon = Icons.sync;
      case ConnectionStatus.disconnected:
        color = Colors.white38;
        label = 'Offline';
        icon = Icons.wifi_off;
      case ConnectionStatus.error:
        color = MeetMindTheme.error;
        label = 'Error';
        icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
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
