import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to store AI consent preference.
const _aiConsentKey = 'ai_consent_granted';

/// Check if the user has already granted AI consent.
Future<bool> hasAiConsent() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_aiConsentKey) ?? false;
}

/// Show the AI consent dialog if consent has not been granted yet.
///
/// Returns `true` if consent was granted (either already or just now),
/// `false` if the user declined.
Future<bool> showAiConsentIfNeeded(BuildContext context) async {
  if (await hasAiConsent()) return true;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _AiConsentDialog(),
  );

  return result ?? false;
}

class _AiConsentDialog extends StatelessWidget {
  const _AiConsentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Text('🤖 ', style: TextStyle(fontSize: 24)),
          Expanded(
            child: Text(
              l10n.aiConsentTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aiConsentBody,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                // Navigate to privacy policy
                context.push('/legal/privacy');
              },
              child: Text(
                l10n.aiConsentLearnMore,
                style: const TextStyle(
                  color: MeetMindTheme.accent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: MeetMindTheme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            l10n.aiConsentDecline,
            style: const TextStyle(color: Colors.white38),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_aiConsentKey, true);
            if (context.mounted) Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: MeetMindTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            l10n.aiConsentAgree,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
