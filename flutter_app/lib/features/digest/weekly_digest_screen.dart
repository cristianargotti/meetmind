import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/providers/subscription_provider.dart';

/// Weekly Digest — AI-generated summary of the past week's meetings.
///
/// Pro-gated feature. Backend integration in Sprint 3.
class WeeklyDigestScreen extends ConsumerWidget {
  const WeeklyDigestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = ref.watch(isProProvider);

    // Pro gate
    if (!isPro) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.digestTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MeetMindTheme.accent.withValues(alpha: 0.3),
                        MeetMindTheme.success.withValues(alpha: 0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.summarize,
                    size: 48,
                    color: MeetMindTheme.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.digestTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.digestSubtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.push('/paywall'),
                  icon: const Icon(Icons.diamond),
                  label: Text(l10n.subscriptionUpgrade),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.summarize,
              size: 20,
              color: MeetMindTheme.accent,
            ),
            const SizedBox(width: 8),
            Text(l10n.digestTitle),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MeetMindTheme.accent.withValues(alpha: 0.15),
                    MeetMindTheme.primary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    l10n.digestSubtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Feb 10 – Feb 16, 2026',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _DigestStatCard(
                    icon: Icons.mic,
                    label: l10n.digestMeetings,
                    value: '0',
                    color: MeetMindTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DigestStatCard(
                    icon: Icons.timer_outlined,
                    label: l10n.digestTimeSpent,
                    value: '0h',
                    color: MeetMindTheme.primary,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _DigestStatCard(
                    icon: Icons.check_circle_outline,
                    label: l10n.digestCompleted,
                    value: '0',
                    color: MeetMindTheme.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DigestStatCard(
                    icon: Icons.pending_actions,
                    label: l10n.digestPending,
                    value: '0',
                    color: MeetMindTheme.warning,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 32),

            // Empty state
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 48,
                    color: MeetMindTheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.digestEmpty,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.digestEmptyHint,
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat card for digest view.
class _DigestStatCard extends StatelessWidget {
  const _DigestStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
