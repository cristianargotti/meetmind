import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/services/auth_service.dart';

/// Legal documents screen — Privacy Policy & Terms of Service.
///
/// Fully localized (EN/ES/PT) and compliant with Apple App Store guidelines.
/// Includes a "Delete My Account" action in Privacy for Apple compliance.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.type, super.key});

  /// 'privacy' or 'terms'
  final String type;

  bool get isPrivacy => type == 'privacy';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: MeetMindTheme.darkBg,
      appBar: AppBar(
        title: Text(
          isPrivacy ? l10n.legalPrivacyPolicy : l10n.legalTermsOfService,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              isPrivacy ? _privacyContent(context, l10n) : _termsContent(l10n),
        ),
      ),
    );
  }

  List<Widget> _privacyContent(BuildContext context, AppLocalizations l10n) {
    return [
      _sectionTitle(l10n.privacyIntro),
      _body(l10n.privacyIntroDesc),
      const SizedBox(height: 20),
      _sectionTitle(l10n.privacyAudioTitle),
      _body(l10n.privacyAudioDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.privacyDataTitle),
      _body(l10n.privacyDataDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.privacySubsTitle),
      _body(l10n.privacySubsDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.privacyRightsTitle),
      _body(l10n.privacyRightsDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.privacyContact),
      const SizedBox(height: 24),

      // ─── Delete Account (Apple requirement) ───
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.privacyDeleteAccount,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.privacyDeleteConfirm,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteConfirmation(context, l10n),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: Text(l10n.privacyDeleteButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _body(l10n.legalLastUpdated),
    ];
  }

  List<Widget> _termsContent(AppLocalizations l10n) {
    return [
      _sectionTitle(l10n.termsIntro),
      _body(l10n.termsIntroDesc),
      const SizedBox(height: 20),
      _sectionTitle(l10n.termsServiceTitle),
      _body(l10n.termsServiceDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.termsSubsTitle),
      _body(l10n.termsSubsDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.termsUseTitle),
      _body(l10n.termsUseDesc),
      const SizedBox(height: 16),
      _sectionTitle(l10n.termsLiabilityTitle),
      _body(l10n.termsLiabilityDesc),
      const SizedBox(height: 16),
      _body(l10n.termsContact),
      const SizedBox(height: 16),
      _body(l10n.legalLastUpdated),
    ];
  }

  /// Show delete account confirmation dialog.
  void _showDeleteConfirmation(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: MeetMindTheme.darkCard,
        title: Text(
          l10n.privacyDeleteAccount,
          style: const TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          l10n.privacyDeleteConfirm,
          style: const TextStyle(color: MeetMindTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await AuthService.instance.deleteAccount();
                if (context.mounted) {
                  GoRouter.of(context).go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.privacyDeleteButton),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: MeetMindTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _body(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: MeetMindTheme.textSecondary,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}
