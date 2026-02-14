import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meetmind/config/app_config.dart';
import 'package:meetmind/config/theme.dart';

/// Settings screen — app configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  String _protocol = 'ws';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final AppConfig config = ref.read(appConfigProvider);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _protocol = config.protocol;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final AppConfig config = ref.read(appConfigProvider);
    await config.setHost(_hostController.text);
    final int? port = int.tryParse(_portController.text);
    if (port != null) {
      await config.setPort(port);
    }
    await config.setProtocol(_protocol);

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend updated: ${config.displayUrl}'),
          backgroundColor: MeetMindTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetDefaults() async {
    final AppConfig config = ref.read(appConfigProvider);
    await config.resetToDefaults();

    setState(() {
      _hostController.text = AppConfig.defaultHost;
      _portController.text = AppConfig.defaultPort.toString();
      _protocol = AppConfig.defaultProtocol;
      _hasChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to defaults'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _markDirty() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Connection ───────────────────────
          const _SectionHeader(title: 'Backend Connection'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Protocol toggle
                  Row(
                    children: [
                      const Text(
                        'Protocol',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(value: 'ws', label: Text('WS')),
                          ButtonSegment<String>(
                            value: 'wss',
                            label: Text('WSS'),
                          ),
                        ],
                        selected: {_protocol},
                        onSelectionChanged: (Set<String> value) {
                          setState(() => _protocol = value.first);
                          _markDirty();
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Host
                  TextField(
                    controller: _hostController,
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(
                      labelText: 'Host (IP or domain)',
                      hintText: '192.168.0.12 or api.meetmind.io',
                      prefixIcon: Icon(Icons.dns_outlined, size: 20),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),

                  // Port
                  TextField(
                    controller: _portController,
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8000',
                      prefixIcon: Icon(Icons.numbers_outlined, size: 20),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Preview URL
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: MeetMindTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MeetMindTheme.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link,
                          size: 14,
                          color: MeetMindTheme.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_protocol://${_hostController.text}:'
                            '${_portController.text}/ws/transcription',
                            style: const TextStyle(
                              color: MeetMindTheme.accent,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reset button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetDefaults,
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reset Defaults'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── AI Models ────────────────────────
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

          // ─── About ────────────────────────────
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
