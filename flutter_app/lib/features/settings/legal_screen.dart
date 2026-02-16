import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:meetmind/config/theme.dart';

/// Legal documents screen — Privacy Policy & Terms of Service.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.type, super.key});

  /// 'privacy' or 'terms'
  final String type;

  bool get isPrivacy => type == 'privacy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeetMindTheme.darkBg,
      appBar: AppBar(
        title: Text(isPrivacy ? 'Privacy Policy' : 'Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isPrivacy ? _privacyContent() : _termsContent(),
        ),
      ),
    );
  }

  List<Widget> _privacyContent() {
    return [
      _sectionTitle('Your Privacy Matters'),
      _body(
        'Aura Meet is designed with privacy at its core. '
        'Here\'s how we handle your data:',
      ),
      const SizedBox(height: 20),
      _sectionTitle('🎙️ Audio Processing'),
      _body(
        '• Speech-to-text runs ON YOUR DEVICE using Parakeet TDT\n'
        '• No audio is ever sent to our servers or stored in the cloud\n'
        '• Audio data stays on your device at all times',
      ),
      const SizedBox(height: 16),
      _sectionTitle('📝 Meeting Data'),
      _body(
        '• Transcripts and insights are sent to our servers for AI analysis only\n'
        '• We use AWS Bedrock (Amazon Nova & Claude) for AI processing\n'
        '• Meeting data is stored securely in PostgreSQL with encryption at rest\n'
        '• You can delete any meeting and its data at any time',
      ),
      const SizedBox(height: 16),
      _sectionTitle('💳 Subscriptions'),
      _body(
        '• Subscription management is handled by RevenueCat\n'
        '• We never see or store your payment details\n'
        '• Apple/Google handles all payment processing',
      ),
      const SizedBox(height: 16),
      _sectionTitle('🔒 Your Rights'),
      _body(
        '• Request deletion of all your data at any time\n'
        '• Export all your meeting data\n'
        '• We do not sell your data to third parties\n'
        '• We do not use your data for advertising',
      ),
      const SizedBox(height: 16),
      _sectionTitle('📧 Contact'),
      _body('For privacy inquiries: privacy@aurameet.app'),
      const SizedBox(height: 16),
      _body(
        'Last updated: February 2026',
      ),
    ];
  }

  List<Widget> _termsContent() {
    return [
      _sectionTitle('Terms of Service'),
      _body(
        'By using Aura Meet, you agree to these terms:',
      ),
      const SizedBox(height: 20),
      _sectionTitle('📱 Service'),
      _body(
        '• Aura Meet is an AI-powered meeting assistant\n'
        '• We provide transcription, insights, and meeting management\n'
        '• Service availability is provided on a best-effort basis\n'
        '• Features may change as we improve the product',
      ),
      const SizedBox(height: 16),
      _sectionTitle('💰 Subscriptions'),
      _body(
        '• Free plan: 3 meetings/week with limited features\n'
        '• Pro plan: \$14.99/month or \$119.99/year\n'
        '• Subscriptions auto-renew unless cancelled\n'
        '• Cancel anytime through App Store or Google Play\n'
        '• No refunds for partial billing periods',
      ),
      const SizedBox(height: 16),
      _sectionTitle('✅ Acceptable Use'),
      _body(
        '• Use Aura Meet for legitimate meeting assistance\n'
        '• Do not attempt to reverse-engineer or abuse the service\n'
        '• Comply with all applicable recording consent laws\n'
        '• You are responsible for obtaining consent from meeting participants',
      ),
      const SizedBox(height: 16),
      _sectionTitle('⚖️ Liability'),
      _body(
        '• AI-generated insights may not be 100% accurate\n'
        '• We are not liable for decisions made based on AI analysis\n'
        '• Service is provided "as-is" without warranties',
      ),
      const SizedBox(height: 16),
      _sectionTitle('📧 Contact'),
      _body('For support: support@aurameet.app'),
      const SizedBox(height: 16),
      _body('Last updated: February 2026'),
    ];
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

  /// Launch external URL for full legal docs.
  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
