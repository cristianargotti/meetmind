import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/subscription_service.dart';

/// Free tier usage banner showing meetings remaining this week.
///
/// Shows a progress bar and upgrade CTA when approaching the limit.
/// Auto-hides for Pro users.
class FreeLimitBanner extends ConsumerWidget {
  const FreeLimitBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = ref.watch(isProProvider);
    if (isPro) return const SizedBox.shrink();

    final sub = ref.watch(subscriptionProvider);
    final used = sub.meetingsThisWeek;
    const limit = FreeTierLimits.meetingsPerWeek;
    final remaining = limit - used;
    final progress = used / limit;
    final isAtLimit = remaining <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MeetMindTheme.darkCard,
        borderRadius: BorderRadius.circular(MeetMindTheme.radiusMd),
        border: Border.all(
          color: isAtLimit
              ? MeetMindTheme.warning.withValues(alpha: 0.3)
              : MeetMindTheme.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAtLimit ? Icons.warning_amber : Icons.mic,
                color: isAtLimit
                    ? MeetMindTheme.warning
                    : MeetMindTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAtLimit
                      ? l10n.freeLimitBannerReached
                      : l10n.freeLimitBannerRemaining(remaining),
                  style: TextStyle(
                    color: isAtLimit
                        ? MeetMindTheme.warning
                        : MeetMindTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAtLimit)
                GestureDetector(
                  onTap: () => context.push('/paywall'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MeetMindTheme.primary, MeetMindTheme.accent],
                      ),
                      borderRadius: BorderRadius.circular(
                        MeetMindTheme.radiusPill,
                      ),
                    ),
                    child: Text(
                      l10n.subscriptionUpgrade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: MeetMindTheme.darkBorder,
              color: isAtLimit ? MeetMindTheme.warning : MeetMindTheme.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.freeLimitBannerUsage(used, limit),
            style: const TextStyle(
              color: MeetMindTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
