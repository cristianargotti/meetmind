import 'package:flutter/material.dart';

import 'package:meetmind/config/theme.dart';

/// Settings screen — app configuration.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection section
          const _SectionHeader(title: 'Backend Connection'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud, color: MeetMindTheme.accent),
              title: const Text('Server URL'),
              subtitle: const Text('localhost:8000'),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {},
            ),
          ),

          const SizedBox(height: 24),

          // AI section
          const _SectionHeader(title: 'AI Models'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.speed, color: MeetMindTheme.success),
                  title: Text('Screening'),
                  subtitle: Text('Claude Haiku 3.5'),
                ),
                Divider(height: 1, indent: 56, color: MeetMindTheme.darkBorder),
                ListTile(
                  leading: Icon(Icons.analytics, color: MeetMindTheme.accent),
                  title: Text('Analysis'),
                  subtitle: Text('Claude Sonnet 4.5'),
                ),
                Divider(height: 1, indent: 56, color: MeetMindTheme.darkBorder),
                ListTile(
                  leading: Icon(Icons.psychology, color: MeetMindTheme.primary),
                  title: Text('Deep Think'),
                  subtitle: Text('Claude Opus 4'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About
          const _SectionHeader(title: 'About'),
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: MeetMindTheme.primaryLight,
              ),
              title: Text('MeetMind'),
              subtitle: Text('v1.0.0 — The most powerful meeting AI'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
