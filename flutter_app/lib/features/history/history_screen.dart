import 'package:flutter/material.dart';
import 'package:meetmind/config/theme.dart';

/// Meeting history screen — list of past sessions.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: MeetMindTheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No meeting history',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white38),
            ),
            const SizedBox(height: 8),
            Text(
              'Past meetings will appear here',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
