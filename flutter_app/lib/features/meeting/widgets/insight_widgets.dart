import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';

/// AI Insights panel — horizontal scrolling insight cards.
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
          return InsightCard(
            insight: insight,
          ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1);
        },
      ),
    );
  }
}

/// Individual insight card with gradient background.
class InsightCard extends StatelessWidget {
  const InsightCard({required this.insight, super.key});

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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MeetMindTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(insight.categoryEmoji, style: const TextStyle(fontSize: 16)),
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
