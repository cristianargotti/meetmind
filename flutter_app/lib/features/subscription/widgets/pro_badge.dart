import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/providers/subscription_provider.dart';

/// Inline "PRO" badge for gated features.
///
/// Shows a shimmer gradient badge. Tapping navigates to the paywall.
class ProBadge extends ConsumerWidget {
  const ProBadge({super.key, this.compact = false});

  /// Compact mode: smaller badge for inline use.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = ref.watch(isProProvider);
    if (isPro) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/paywall'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MeetMindTheme.primary, MeetMindTheme.accent],
          ),
          borderRadius: BorderRadius.circular(MeetMindTheme.radiusPill),
        ),
        child: Text(
          l10n.proBadge,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Gated feature wrapper.
///
/// Shows the child if Pro, otherwise shows a locked overlay that taps to paywall.
class ProGate extends ConsumerWidget {
  const ProGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = ref.watch(isProProvider);
    if (isPro) return child;

    return GestureDetector(
      onTap: () => context.push('/paywall'),
      child: Stack(
        children: [
          Opacity(opacity: 0.4, child: IgnorePointer(child: child)),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MeetMindTheme.darkCard.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(MeetMindTheme.radiusSm),
                  border: Border.all(color: MeetMindTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: MeetMindTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.proGateLocked,
                      style: const TextStyle(
                        color: MeetMindTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ProBadge(compact: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
