import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';

/// Summary panel — structured post-meeting summary with action items.
class SummaryPanel extends StatelessWidget {
  const SummaryPanel({
    required this.summary,
    required this.isLoading,
    required this.hasTranscript,
    required this.onGenerate,
    super.key,
  });

  /// The generated summary, if available.
  final MeetingSummary? summary;

  /// Whether summary is currently being generated.
  final bool isLoading;

  /// Whether there is transcript text available to summarize.
  final bool hasTranscript;

  /// Callback to request summary generation.
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _LoadingState();
    }

    if (summary == null) {
      return _EmptyState(hasTranscript: hasTranscript, onGenerate: onGenerate);
    }

    return _SummaryContent(summary: summary!);
  }
}

/// Loading state while summary is being generated.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: MeetMindTheme.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Generating summary...',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is analyzing your meeting transcript',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

/// Empty state before summary generation.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasTranscript, required this.onGenerate});

  final bool hasTranscript;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.summarize_outlined,
            size: 64,
            color: MeetMindTheme.warning.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Meeting Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            hasTranscript
                ? 'Generate a structured summary with\n'
                    'decisions, action items, and follow-ups.'
                : 'Start recording to capture transcript.\n'
                    'Summary will be available after.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: hasTranscript ? onGenerate : null,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate Summary'),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

/// Rendered summary content with structured cards.
class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final MeetingSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // Title + copy button
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                summary.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy as Markdown',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: summary.toMarkdown()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Summary copied as Markdown'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),

        // Overview
        const SizedBox(height: 12),
        Text(
          summary.summary,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
        ),

        if (summary.latencyMs != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Generated in ${summary.latencyMs}ms',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],

        // Card groups
        if (summary.decisions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SummaryCardGroup(
            title: '📌 Decisions',
            items: summary.decisions,
            accentColor: MeetMindTheme.primary,
          ),
        ],

        if (summary.actionItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _SummaryCardGroup(
            title: '✅ Action Items',
            items: summary.actionItems,
            accentColor: MeetMindTheme.success,
          ),
        ],

        if (summary.keyTopics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _SummaryCardGroup(
            title: '💬 Key Topics',
            items: summary.keyTopics,
            accentColor: MeetMindTheme.accent,
          ),
        ],

        if (summary.followUps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _SummaryCardGroup(
            title: '📅 Follow-Ups',
            items: summary.followUps,
            accentColor: MeetMindTheme.warning,
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

/// A group of summary items with a colored accent.
class _SummaryCardGroup extends StatelessWidget {
  const _SummaryCardGroup({
    required this.title,
    required this.items,
    required this.accentColor,
  });

  final String title;
  final List<String> items;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (String item) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              item,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }
}
