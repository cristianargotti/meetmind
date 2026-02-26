import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/features/meeting/widgets/ai_consent_dialog.dart';
import 'package:meetmind/features/subscription/widgets/free_limit_banner.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/providers/auth_provider.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/meeting_api_service.dart';

/// Provider that fetches recent meetings from the backend.
final _recentMeetingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  // Re-fetch whenever auth state changes
  final auth = ref.watch(authProvider);
  // Guest mode — no backend, return empty
  if (auth.isGuest) return [];
  final api = MeetingApiService();
  try {
    return await api.listMeetings(limit: 5);
  } catch (_) {
    return [];
  } finally {
    api.dispose();
  }
});

/// Provider that fetches pending action items count.
final _pendingActionsCountProvider = FutureProvider<int>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.isGuest) return 0;
  final api = MeetingApiService();
  try {
    final items = await api.getPendingActions(limit: 100);
    return items.length;
  } catch (_) {
    return 0;
  } finally {
    api.dispose();
  }
});

/// Home screen — meeting hub with quick-start action.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final MeetingSession? meeting = ref.watch(meetingProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName = (user?['name'] as String?)?.split(' ').first ?? '';
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header with user avatar + greeting
              Row(
                children: [
                  // User avatar
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: avatarUrl.isEmpty
                            ? const LinearGradient(
                                colors: [
                                  MeetMindTheme.primary,
                                  Color(0xFF7C3AED),
                                ],
                              )
                            : null,
                        image: avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                        border: Border.all(
                          color: MeetMindTheme.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: avatarUrl.isEmpty
                          ? Center(
                              child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName.isNotEmpty
                              ? '$greeting, $userName'
                              : greeting,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.homeSubtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Settings icon
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),

              const SizedBox(height: 24),

              // Quick Start Card — tappable to start meeting
              GestureDetector(
                onTap: () async {
                  final canStart = ref.read(canStartMeetingProvider);
                  if (canStart) {
                    final consent = await showAiConsentIfNeeded(context);
                    if (!context.mounted || !consent) return;
                    context.push('/meeting');
                  } else {
                    context.push('/paywall');
                  }
                },
                child: _QuickStartCard(
                  isActive:
                      meeting != null && meeting.status.name == 'recording',
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.1),
              ),

              // Free tier usage banner
              const FreeLimitBanner(),

              const SizedBox(height: 16),

              // Stats Row — derive from current session
              Builder(
                builder: (context) {
                  final remaining = ref.watch(meetingsRemainingProvider);
                  // Show meetings remaining this week (Pro = ∞)
                  final todayCount =
                      remaining == -1 ? '∞' : remaining.toString();
                  final insightCount =
                      meeting?.insights.length.toString() ?? '0';
                  final pendingActions = ref.watch(
                    _pendingActionsCountProvider,
                  );
                  final actionCount = pendingActions.when(
                    data: (count) => count.toString(),
                    loading: () => '…',
                    error: (_, _) => '0',
                  );
                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.mic,
                          label: l10n.homeToday,
                          value: todayCount,
                          color: MeetMindTheme.accent,
                          onTap: () => context.push('/history'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.insights,
                          label: l10n.homeInsights,
                          value: insightCount,
                          color: MeetMindTheme.success,
                          onTap: meeting != null
                              ? () => context.push('/meeting')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.task_alt,
                          label: l10n.homeActions,
                          value: actionCount,
                          color: MeetMindTheme.warning,
                          onTap: () => context.push('/history'),
                        ),
                      ),
                    ]
                        .animate(interval: 100.ms)
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.1),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Recent Meetings Header
              Text(
                l10n.homeRecentMeetings,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),

              const SizedBox(height: 12),

              // Recent meetings from API
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final asyncMeetings = ref.watch(_recentMeetingsProvider);
                    return asyncMeetings.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: MeetMindTheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      error: (_, _) => _buildEmptyState(context, l10n),
                      data: (meetings) {
                        if (meetings.isEmpty) {
                          return _buildEmptyState(context, l10n);
                        }
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: meetings.length,
                          itemBuilder: (context, index) {
                            final m = meetings[index];
                            final title =
                                m['title'] as String? ?? 'Untitled Meeting';
                            final startedAt = m['started_at'] as String?;
                            final durationSecs =
                                m['duration_secs'] as int? ?? 0;

                            String subtitle = '';
                            if (startedAt != null) {
                              try {
                                final dt = DateTime.parse(startedAt).toLocal();
                                subtitle = DateFormat(
                                  'MMM d · h:mm a',
                                ).format(dt);
                              } catch (_) {
                                subtitle = '';
                              }
                            }
                            if (durationSecs > 0) {
                              final d = Duration(seconds: durationSecs);
                              subtitle +=
                                  ' · ${d.inMinutes}m ${d.inSeconds % 60}s';
                            }

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: MeetMindTheme.primaryDim,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.mic_rounded,
                                  color: MeetMindTheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white24,
                                size: 20,
                              ),
                              onTap: () => context.push('/meeting/${m['id']}'),
                            )
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                    milliseconds: 400 + index * 80,
                                  ),
                                  duration: 300.ms,
                                )
                                .slideX(begin: 0.05);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Navigation — Material 3
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (int index) {
          switch (index) {
            case 1:
              context.push('/history');
            case 2:
              context.push('/settings');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTitle.split(' ').first,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.historyTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTitle,
          ),
        ],
      ),

      // FAB — Start Meeting (gated by subscription)
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          final canStart = ref.read(canStartMeetingProvider);
          if (canStart) {
            final consent = await showAiConsentIfNeeded(context);
            if (!context.mounted || !consent) return;
            context.push('/meeting');
          } else {
            context.push('/paywall');
          }
        },
        child: const Icon(Icons.mic, size: 36),
      ).animate().scale(delay: 600.ms, duration: 400.ms),
    );
  }

  /// Empty state fallback for the recent meetings section.
  static Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 64,
              height: 64,
              opacity: const AlwaysStoppedAnimation(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.homeNoMeetings,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeNoMeetingsHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white24),
          ),
        ],
      ).animate().fadeIn(delay: 500.ms),
    );
  }
}

/// Quick-start hero card.
class _QuickStartCard extends ConsumerWidget {
  const _QuickStartCard({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MeetMindTheme.primary, Color(0xFF4A42D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MeetMindTheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.graphic_eq : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MeetMindTheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: MeetMindTheme.success,
                        size: 8,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.homeLive,
                        style: const TextStyle(
                          color: MeetMindTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isActive ? l10n.homeMeetingInProgress : l10n.homeStartMeeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isActive ? l10n.homeAiListening : l10n.homeTranscribeRealtime,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat card.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
