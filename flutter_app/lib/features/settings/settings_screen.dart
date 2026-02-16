import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:meetmind/config/app_config.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/preferences_provider.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/user_preferences.dart';

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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsBackendUpdated(config.displayUrl)),
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsResetDone),
          duration: const Duration(seconds: 2),
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
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(preferencesProvider);
    final prefsNotifier = ref.read(preferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save, size: 18),
              label: Text(l10n.settingsSave),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Language ───────────────────────────
          _SectionHeader(title: l10n.settingsLanguage),
          Card(
            child: Column(
              children: [
                // UI Language
                ListTile(
                  leading: const Icon(
                    Icons.language,
                    color: MeetMindTheme.accent,
                  ),
                  title: Text(l10n.settingsUiLanguage),
                  trailing: DropdownButton<AppLocale>(
                    value: prefs.locale,
                    underline: const SizedBox.shrink(),
                    dropdownColor: MeetMindTheme.darkCard,
                    items: AppLocale.values.map((locale) {
                      return DropdownMenuItem(
                        value: locale,
                        child: Text(
                          '${locale.flag} ${locale.displayName}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        prefsNotifier.setLocale(value);
                      }
                    },
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: MeetMindTheme.darkBorder,
                ),
                // Transcription Language
                ListTile(
                  leading: const Icon(
                    Icons.mic,
                    color: MeetMindTheme.primaryLight,
                  ),
                  title: Text(l10n.settingsTranscriptionLanguage),
                  trailing: DropdownButton<TranscriptionLanguage>(
                    value: prefs.transcriptionLanguage,
                    underline: const SizedBox.shrink(),
                    dropdownColor: MeetMindTheme.darkCard,
                    items: TranscriptionLanguage.values.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(
                          '${lang.icon} ${lang.displayName}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        prefsNotifier.setTranscriptionLanguage(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Appearance ─────────────────────────
          _SectionHeader(title: l10n.settingsAppearance),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.palette_outlined,
                color: MeetMindTheme.primary,
              ),
              title: Text(l10n.settingsThemeMode),
              trailing: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.settingsThemeDark),
                    icon: const Icon(Icons.dark_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.settingsThemeLight),
                    icon: const Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.settingsThemeSystem),
                    icon: const Icon(Icons.settings_brightness, size: 16),
                  ),
                ],
                selected: {prefs.themeMode},
                onSelectionChanged: (Set<ThemeMode> value) {
                  prefsNotifier.setThemeMode(value.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Audio ──────────────────────────────
          _SectionHeader(title: l10n.settingsAudio),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.graphic_eq,
                color: MeetMindTheme.success,
              ),
              title: Text(l10n.settingsAudioQuality),
              trailing: SegmentedButton<AudioQuality>(
                segments: [
                  ButtonSegment(
                    value: AudioQuality.standard,
                    label: Text(l10n.settingsAudioStandard),
                  ),
                  ButtonSegment(
                    value: AudioQuality.high,
                    label: Text(l10n.settingsAudioHigh),
                  ),
                ],
                selected: {prefs.audioQuality},
                onSelectionChanged: (Set<AudioQuality> value) {
                  prefsNotifier.setAudioQuality(value.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Notifications ──────────────────────
          _SectionHeader(title: l10n.settingsNotifications),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_outlined,
                    color: MeetMindTheme.warning,
                  ),
                  title: Text(l10n.settingsNotificationsEnabled),
                  value: prefs.notificationsEnabled,
                  onChanged: (value) =>
                      prefsNotifier.setNotificationsEnabled(value),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: MeetMindTheme.darkBorder,
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.vibration,
                    color: MeetMindTheme.textSecondary,
                  ),
                  title: Text(l10n.settingsHapticFeedback),
                  value: prefs.hapticFeedback,
                  onChanged: (value) =>
                      prefsNotifier.setHapticFeedback(value),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Connection ─────────────────────────
          _SectionHeader(title: l10n.settingsBackendConnection),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Protocol toggle
                  Row(
                    children: [
                      Text(
                        l10n.settingsProtocol,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'ws',
                            label: Text('WS'),
                          ),
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
                    decoration: InputDecoration(
                      labelText: l10n.settingsHost,
                      hintText: l10n.settingsHostHint,
                      prefixIcon: const Icon(Icons.dns_outlined, size: 20),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),

                  // Port
                  TextField(
                    controller: _portController,
                    onChanged: (_) => _markDirty(),
                    decoration: InputDecoration(
                      labelText: l10n.settingsPort,
                      hintText: l10n.settingsPortHint,
                      prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
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
                      label: Text(l10n.settingsResetDefaults),
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

          // ─── AI Models ──────────────────────────
          _SectionHeader(title: l10n.settingsAiModels),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.speed,
                    color: MeetMindTheme.success,
                  ),
                  title: Text(l10n.settingsScreening),
                  subtitle: const Text('Claude Haiku 3.5'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: MeetMindTheme.darkBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.analytics,
                    color: MeetMindTheme.accent,
                  ),
                  title: Text(l10n.settingsAnalysis),
                  subtitle: const Text('Claude Sonnet 4.5'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: MeetMindTheme.darkBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.psychology,
                    color: MeetMindTheme.primary,
                  ),
                  title: Text(l10n.settingsDeepThink),
                  subtitle: const Text('Claude Opus 4'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Subscription ───────────────────────
          _SectionHeader(title: l10n.subscriptionTitle),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.diamond,
                    color: MeetMindTheme.primary,
                  ),
                  title: Text(
                    ref.watch(subscriptionTierProvider).displayName,
                  ),
                  subtitle: Text(
                    ref.watch(isProProvider)
                        ? l10n.subscriptionActive
                        : l10n.subscriptionFreePlan(3),
                  ),
                  trailing: ref.watch(isProProvider)
                      ? null
                      : ElevatedButton(
                          onPressed: () => context.push('/paywall'),
                          child: Text(l10n.subscriptionUpgrade),
                        ),
                ),
                if (ref.watch(isProProvider))
                  ListTile(
                    leading: const Icon(
                      Icons.manage_accounts,
                      color: MeetMindTheme.textSecondary,
                    ),
                    title: Text(l10n.subscriptionManage),
                    onTap: () => context.push('/paywall'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── About ──────────────────────────────
          _SectionHeader(title: l10n.aboutTitle),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: MeetMindTheme.primaryLight,
              ),
              title: const Text('Aura Meet'),
              subtitle: Text(l10n.aboutVersion('5.0.0')),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Legal ──────────────────────────────
          _SectionHeader(title: l10n.legalPrivacyPolicy.split(' ').first),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.shield_outlined,
                    color: MeetMindTheme.accent,
                  ),
                  title: Text(l10n.legalPrivacyPolicy),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MeetMindTheme.textTertiary,
                  ),
                  onTap: () => context.push('/legal/privacy'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: MeetMindTheme.darkBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: MeetMindTheme.accent,
                  ),
                  title: Text(l10n.legalTermsOfService),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MeetMindTheme.textTertiary,
                  ),
                  onTap: () => context.push('/legal/terms'),
                ),
              ],
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
