import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';

/// Dedicated Insights tab — full-panel feed of proactive AI suggestions.
class InsightsTab extends StatelessWidget {
  const InsightsTab({required this.insights, super.key});

  final List<AIInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const _EmptyInsightsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: insights.length,
      itemBuilder: (BuildContext context, int index) {
        final AIInsight insight = insights[insights.length - 1 - index];
        return InsightCard(
          insight: insight,
          index: index,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06);
      },
    );
  }
}

/// Empty state when no insights have arrived yet.
class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  MeetMindTheme.primary.withValues(alpha: 0.2),
                  MeetMindTheme.accent.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 36,
              color: MeetMindTheme.primaryLight,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AI Insights',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: MeetMindTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Proactive AI analysis will appear here\n'
            'as the conversation unfolds.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MeetMindTheme.textTertiary,
              height: 1.6,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

/// Horizontal insights panel (kept for backward compatibility).
class InsightsPanel extends StatelessWidget {
  const InsightsPanel({required this.insights, super.key});

  final List<AIInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: const BoxDecoration(
        color: MeetMindTheme.darkSurface,
        border: Border(bottom: BorderSide(color: MeetMindTheme.darkBorder)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        itemBuilder: (BuildContext context, int index) {
          final AIInsight insight = insights[insights.length - 1 - index];
          return _CompactInsightCard(insight: insight)
              .animate()
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.1);
        },
      ),
    );
  }
}

/// Full-width insight card for the dedicated Insights tab.
class InsightCard extends StatelessWidget {
  const InsightCard({required this.insight, this.index = 0, super.key});

  final AIInsight insight;
  final int index;

  /// Rotating accent colors for visual variety.
  static const List<Color> _accentColors = [
    MeetMindTheme.primary,
    MeetMindTheme.accent,
    MeetMindTheme.copilot,
    MeetMindTheme.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _accentColors[index % _accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MeetMindTheme.darkCard,
        borderRadius: BorderRadius.circular(MeetMindTheme.radiusMd),
        border: Border.all(color: MeetMindTheme.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored accent bar
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(MeetMindTheme.radiusMd),
                bottomLeft: Radius.circular(MeetMindTheme.radiusMd),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: emoji + title
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            insight.categoryEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight.title,
                          style: const TextStyle(
                            color: MeetMindTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Analysis body
                  Text(
                    insight.analysis,
                    style: const TextStyle(
                      color: MeetMindTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Recommendation
                  if (insight.recommendation.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              insight.recommendation,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact insight card for horizontal scrolling (legacy panel).
class _CompactInsightCard extends StatelessWidget {
  const _CompactInsightCard({required this.insight});

  final AIInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MeetMindTheme.accent.withValues(alpha: 0.1),
            MeetMindTheme.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(MeetMindTheme.radiusMd),
        border: Border.all(
          color: MeetMindTheme.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(insight.categoryEmoji,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.analysis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            insight.recommendation,
            style: const TextStyle(
              color: MeetMindTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
