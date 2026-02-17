import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/features/subscription/widgets/free_limit_banner.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/providers/auth_provider.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/providers/subscription_provider.dart';

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

              const SizedBox(height: 40),

              // Quick Start Card
              _QuickStartCard(
                    isActive:
                        meeting != null && meeting.status.name == 'recording',
                  )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.1),

              // Free tier usage banner
              const FreeLimitBanner(),

              const SizedBox(height: 24),

              // Stats Row — derive from current session
              Builder(
                builder: (context) {
                  final isActive = meeting != null && meeting.status.name == 'recording';
                  final todayCount = isActive ? '1' : '0';
                  final insightCount = meeting?.insights.length.toString() ?? '0';
                  const actionCount = '0'; // TODO: connect to action items provider
                  return Row(
                    children:
                        [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.mic,
                                  label: l10n.homeToday,
                                  value: todayCount,
                                  color: MeetMindTheme.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.insights,
                                  label: l10n.homeInsights,
                                  value: insightCount,
                                  color: MeetMindTheme.success,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.task_alt,
                                  label: l10n.homeActions,
                                  value: actionCount,
                                  color: MeetMindTheme.warning,
                                ),
                              ),
                            ]
                            .animate(interval: 100.ms)
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.1),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Recent Meetings Header
              Text(
                l10n.homeRecentMeetings,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Empty state
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
              context.push('/ask-aura');
            case 2:
              context.push('/history');
            case 3:
              context.push('/settings');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTitle.split(' ').first,
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Ask Aura',
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
        onPressed: () {
          final canStart = ref.read(canStartMeetingProvider);
          if (canStart) {
            context.push('/meeting');
          } else {
            context.push('/paywall');
          }
        },
        child: const Icon(Icons.mic, size: 36),
      ).animate().scale(delay: 600.ms, duration: 400.ms),
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
    );
  }
}
