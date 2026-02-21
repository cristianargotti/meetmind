import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/auth_provider.dart';
import 'package:meetmind/providers/preferences_provider.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/user_preferences.dart';

/// Settings screen — app configuration.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(preferencesProvider);
    final prefsNotifier = ref.read(preferencesProvider.notifier);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Account ─────────────────────────────
          _SectionHeader(title: l10n.accountTitle),
          _AccountCard(authState: authState, ref: ref, l10n: l10n),

          const SizedBox(height: 24),

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

          // Hidden for launch — Appearance (light theme not ready)
          // Will re-enable in Sprint 2 with a proper light theme.



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
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
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
                  onChanged: prefsNotifier.setNotificationsEnabled,
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
                  onChanged: prefsNotifier.setHapticFeedback,
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
                  title: Text(ref.watch(subscriptionTierProvider).displayName),
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

/// Account card with user info, sign out, and delete account.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.authState,
    required this.ref,
    required this.l10n,
  });

  final AuthState authState;
  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final user = authState.user;
    final name = user?['name'] as String? ?? '';
    final email = user?['email'] as String? ?? '';
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final displayName = name.isNotEmpty ? name : l10n.accountGuestUser;
    final initials = displayName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Card(
      child: Column(
        children: [
          // User info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarUrl.isEmpty
                        ? const LinearGradient(
                            colors: [MeetMindTheme.primary, Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Name + email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: MeetMindTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            email,
                            style: const TextStyle(
                              color: MeetMindTheme.textTertiary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: MeetMindTheme.darkBorder,
          ),

          // Sign Out
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: MeetMindTheme.warning,
            ),
            title: Text(l10n.accountSignOut),
            trailing: const Icon(
              Icons.chevron_right,
              color: MeetMindTheme.textTertiary,
            ),
            onTap: () => _handleSignOut(context),
          ),

          const Divider(height: 1, indent: 56, color: MeetMindTheme.darkBorder),

          // Delete Account
          ListTile(
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: MeetMindTheme.error,
            ),
            title: Text(
              l10n.accountDeleteAccount,
              style: const TextStyle(color: MeetMindTheme.error),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: MeetMindTheme.textTertiary,
            ),
            onTap: () => _handleDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  void _handleSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountSignOut),
        content: Text(l10n.accountSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: MeetMindTheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.accountDeleteConfirmTitle)),
          ],
        ),
        content: Text(l10n.accountDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MeetMindTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authProvider.notifier).deleteAccount();
                if (context.mounted) context.go('/login');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.commonError}: $e'),
                      backgroundColor: MeetMindTheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.accountDeleteConfirmButton),
          ),
        ],
      ),
    );
  }
}
