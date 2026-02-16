import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/providers/meeting_provider.dart';

/// Home screen — meeting hub with quick-start action.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MeetingSession? meeting = ref.watch(meetingProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Header
              Text(
                'MeetMind',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

              const SizedBox(height: 4),

              Text(
                'Your AI meeting companion',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 40),

              // Quick Start Card
              _QuickStartCard(
                isActive: meeting != null && meeting.status.name == 'recording',
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Stats Row
              Row(
                children: [
                  const Expanded(
                    child: _StatCard(
                      icon: Icons.mic,
                      label: 'Today',
                      value: '0',
                      color: MeetMindTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _StatCard(
                      icon: Icons.insights,
                      label: 'Insights',
                      value: '0',
                      color: MeetMindTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _StatCard(
                      icon: Icons.task_alt,
                      label: 'Actions',
                      value: '0',
                      color: MeetMindTheme.warning,
                    ),
                  ),
                ]
                    .animate(interval: 100.ms)
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.1),
              ),

              const SizedBox(height: 32),

              // Recent Meetings Header
              Text(
                'Recent Meetings',
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
                      Icon(
                        Icons.headset_mic_rounded,
                        size: 64,
                        color: MeetMindTheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No meetings yet',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white38),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to start your first meeting',
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

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (int index) {
          switch (index) {
            case 1:
              context.push('/history');
            case 2:
              context.push('/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),

      // FAB — Start Meeting
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => context.push('/meeting'),
        child: const Icon(Icons.mic, size: 36),
      ).animate().scale(delay: 600.ms, duration: 400.ms),
    );
  }
}

/// Quick-start hero card.
class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: MeetMindTheme.success,
                        size: 8,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
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
            isActive ? 'Meeting in Progress' : 'Start a Meeting',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isActive
                ? 'AI is listening and analyzing...'
                : 'MeetMind will transcribe and analyze in real-time',
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
