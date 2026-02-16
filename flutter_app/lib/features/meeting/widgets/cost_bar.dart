import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';

/// Thin cost tracking bar — shows AI spend vs session budget.
class CostBar extends StatelessWidget {
  const CostBar({required this.costData, super.key});

  /// Current cost data, null if no AI calls have been made yet.
  final CostData? costData;

  @override
  Widget build(BuildContext context) {
    if (costData == null) return const SizedBox.shrink();

    final CostData data = costData!;
    final double pct = (data.budgetPct * 100).clamp(0, 100);

    // Color coding: green < 50%, yellow < 80%, red >= 80%
    final Color barColor = pct >= 80
        ? MeetMindTheme.error
        : pct >= 50
            ? MeetMindTheme.warning
            : MeetMindTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MeetMindTheme.darkBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.monetization_on_outlined,
                    size: 14,
                    color: barColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '\$${data.totalCostUsd.toStringAsFixed(3)}',
                    style: TextStyle(
                      color: barColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Text(
                data.budgetExceeded
                    ? '⚠️ Budget exceeded'
                    : '\$${data.budgetRemainingUsd.toStringAsFixed(2)} left',
                style: TextStyle(
                  color: data.budgetExceeded
                      ? MeetMindTheme.error
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: MeetMindTheme.darkCard,
                color: barColor,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
