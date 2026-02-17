// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aura Meet';

  @override
  String get appTagline => 'Your AI meeting copilot';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginWithApple => 'Continue with Apple';

  @override
  String get loginSkip => 'Continue without account';

  @override
  String get homeTitle => 'Aura Meet';

  @override
  String get homeSubtitle => 'Your AI meeting companion';

  @override
  String get homeToday => 'Today';

  @override
  String get homeInsights => 'Insights';

  @override
  String get homeActions => 'Actions';

  @override
  String get homeRecentMeetings => 'Recent Meetings';

  @override
  String get homeNoMeetings => 'No meetings yet';

  @override
  String get homeNoMeetingsHint =>
      'Tap the button below to start your first meeting';

  @override
  String get homeStartMeeting => 'Start a Meeting';

  @override
  String get homeMeetingInProgress => 'Meeting in Progress';

  @override
  String get homeAiListening => 'AI is listening and analyzing...';

  @override
  String get homeTranscribeRealtime =>
      'Aura will transcribe and analyze in real-time';

  @override
  String get homeLive => 'LIVE';

  @override
  String get meetingTitle => 'Meeting';

  @override
  String get meetingRecording => 'Recording';

  @override
  String get meetingPaused => 'Paused';

  @override
  String get meetingStopped => 'Stopped';

  @override
  String get meetingStart => 'Start';

  @override
  String get meetingPause => 'Pause';

  @override
  String get meetingResume => 'Resume';

  @override
  String get meetingStop => 'Stop';

  @override
  String get meetingTranscript => 'Transcript';

  @override
  String get meetingInsights => 'Insights';

  @override
  String get meetingSummary => 'Summary';

  @override
  String get meetingNoTranscript => 'Waiting for audio...';

  @override
  String get meetingNoInsights => 'No insights yet';

  @override
  String get meetingCopySummary => 'Copy Summary';

  @override
  String get meetingSummaryCopied => 'Summary copied to clipboard';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmpty => 'No meeting history';

  @override
  String get historyEmptyHint => 'Your past meetings will appear here';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsUiLanguage => 'App Language';

  @override
  String get settingsTranscriptionLanguage => 'Transcription Language';

  @override
  String get settingsAutoDetect => 'Auto-detect';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAudioQuality => 'Recording Quality';

  @override
  String get settingsAudioStandard => 'Standard';

  @override
  String get settingsAudioHigh => 'High';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsEnabled => 'Meeting Reminders';

  @override
  String get settingsHapticFeedback => 'Haptic Feedback';

  @override
  String get settingsBackendConnection => 'Backend Connection';

  @override
  String get settingsProtocol => 'Protocol';

  @override
  String get settingsHost => 'Host (IP or domain)';

  @override
  String get settingsHostHint => '192.168.0.12 or api.aurameet.io';

  @override
  String get settingsPort => 'Port';

  @override
  String get settingsPortHint => '8000';

  @override
  String get settingsResetDefaults => 'Reset Defaults';

  @override
  String settingsBackendUpdated(String url) {
    return 'Backend updated: $url';
  }

  @override
  String get settingsResetDone => 'Reset to defaults';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsScreening => 'Screening';

  @override
  String get settingsAnalysis => 'Analysis';

  @override
  String get settingsDeepThink => 'Deep Think';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSignOut => 'Sign Out';

  @override
  String get accountSignOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get accountDeleteAccount => 'Delete Account';

  @override
  String get accountDeleteConfirmTitle => 'Delete Account?';

  @override
  String get accountDeleteConfirmBody =>
      'This will permanently delete your account and all your meeting data. This action cannot be undone.';

  @override
  String get accountDeleteConfirmButton => 'Delete Everything';

  @override
  String get accountGuestUser => 'Guest User';

  @override
  String get accountLinkedAccounts => 'Linked Accounts';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authName => 'Name';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authForgotPassword => 'Forgot Password?';

  @override
  String get authToggleToRegister => 'Don\'t have an account? Sign up';

  @override
  String get authToggleToLogin => 'Already have an account? Sign in';

  @override
  String get authPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get authFillFields => 'Enter email and password';

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String get subscriptionFree => 'Free';

  @override
  String get subscriptionPro => 'Pro';

  @override
  String get subscriptionTeam => 'Team';

  @override
  String get subscriptionBusiness => 'Business';

  @override
  String get subscriptionActive => 'Active subscription';

  @override
  String subscriptionFreePlan(int limit) {
    return 'Free plan — $limit meetings/week';
  }

  @override
  String get subscriptionManage => 'Manage Subscription';

  @override
  String get subscriptionUpgrade => 'Upgrade';

  @override
  String get paywallTitle => 'Unlock Aura Pro';

  @override
  String get paywallSubtitle => 'Your AI meeting copilot, unleashed';

  @override
  String get paywallMonthly => 'Monthly';

  @override
  String get paywallYearly => 'Yearly';

  @override
  String paywallSaveBadge(int percent) {
    return 'Save $percent%';
  }

  @override
  String paywallStartProMonthly(String price) {
    return 'Start Pro — $price/month';
  }

  @override
  String paywallStartProYearly(String price) {
    return 'Start Pro — $price/year';
  }

  @override
  String get paywallRestore => 'Restore Purchases';

  @override
  String get paywallRestoreSuccess => 'Purchases restored';

  @override
  String get paywallRestoreNone => 'No purchases found to restore';

  @override
  String get paywallPurchaseSuccess => 'Welcome to Aura Pro! 🎉';

  @override
  String get paywallPurchaseCancelled => 'Purchase cancelled';

  @override
  String paywallPurchaseError(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get paywallFeatureFree => 'Free';

  @override
  String get paywallFeaturePro => 'Pro';

  @override
  String get paywallFeatureMeetings => 'Meetings';

  @override
  String paywallFeatureMeetingsFreeValue(int limit) {
    return '$limit/week';
  }

  @override
  String get paywallFeatureMeetingsProValue => 'Unlimited';

  @override
  String get paywallFeatureTranscription => 'Transcription';

  @override
  String get paywallFeatureInsights => 'AI Insights';

  @override
  String get paywallFeatureAskAura => 'Ask Aura';

  @override
  String get paywallFeatureExport => 'Full Export';

  @override
  String get paywallFeatureDigest => 'Weekly Digest';

  @override
  String get paywallLegal => 'Cancel anytime. Recurring billing.';

  @override
  String freeLimitBannerRemaining(int remaining) {
    return '$remaining meeting(s) left this week';
  }

  @override
  String get freeLimitBannerReached => 'Weekly limit reached';

  @override
  String freeLimitBannerUsage(int used, int limit) {
    return '$used / $limit meetings';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get proGateLocked => 'Pro Feature';

  @override
  String get proGateUnlock => 'Unlock';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalLastUpdated => 'Last updated: February 2026';

  @override
  String get privacyIntro => 'Your Privacy Matters';

  @override
  String get privacyIntroDesc =>
      'Aura Meet is designed with privacy at its core. Here\'s how we handle your data:';

  @override
  String get privacyAudioTitle => '🎙️ Audio Processing';

  @override
  String get privacyAudioDesc =>
      '• Speech-to-text runs ON YOUR DEVICE\n• No audio is ever sent to our servers or stored in the cloud\n• Audio data stays on your device at all times';

  @override
  String get privacyDataTitle => '📝 Meeting Data';

  @override
  String get privacyDataDesc =>
      '• Transcripts are sent to our servers for AI analysis only\n• Meeting data is stored securely with encryption at rest\n• You can delete any meeting and its data at any time';

  @override
  String get privacySubsTitle => '💳 Subscriptions';

  @override
  String get privacySubsDesc =>
      '• We never see or store your payment details\n• Apple/Google handles all payment processing';

  @override
  String get privacyRightsTitle => '🔒 Your Rights';

  @override
  String get privacyRightsDesc =>
      '• Request deletion of all your data at any time\n• Export all your meeting data\n• We do not sell your data to third parties\n• We do not use your data for advertising';

  @override
  String get privacyContact => 'For privacy inquiries: privacy@aurameet.live';

  @override
  String get privacyDeleteAccount => 'Delete My Account';

  @override
  String get privacyDeleteConfirm =>
      'This will permanently delete your account and all associated data. This action cannot be undone.';

  @override
  String get privacyDeleteButton => 'Delete Everything';

  @override
  String get termsIntro => 'Terms of Service';

  @override
  String get termsIntroDesc => 'By using Aura Meet, you agree to these terms:';

  @override
  String get termsServiceTitle => '📱 Service';

  @override
  String get termsServiceDesc =>
      '• Aura Meet is an AI-powered meeting assistant\n• We provide transcription, insights, and meeting management\n• Service availability is provided on a best-effort basis\n• Features may change as we improve the product';

  @override
  String get termsSubsTitle => '💰 Subscriptions';

  @override
  String get termsSubsDesc =>
      '• Free plan: 3 meetings/week with limited features\n• Subscriptions auto-renew unless cancelled\n• Cancel anytime through App Store or Google Play\n• No refunds for partial billing periods';

  @override
  String get termsUseTitle => '✅ Acceptable Use';

  @override
  String get termsUseDesc =>
      '• Use Aura Meet for legitimate meeting assistance\n• Comply with all applicable recording consent laws\n• You are responsible for obtaining consent from meeting participants';

  @override
  String get termsLiabilityTitle => '⚖️ Liability';

  @override
  String get termsLiabilityDesc =>
      '• AI-generated insights may not be 100% accurate\n• We are not liable for decisions made based on AI analysis\n• Service is provided \"as-is\" without warranties';

  @override
  String get termsContact => 'For support: support@aurameet.live';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'v$version — Your AI meeting copilot';
  }

  @override
  String get askAuraTitle => 'Ask Aura';

  @override
  String get askAuraSubtitle => 'Chat with your meetings';

  @override
  String get askAuraPlaceholder => 'Ask about your meetings...';

  @override
  String get askAuraEmpty => 'Ask me anything about your meetings';

  @override
  String get askAuraEmptyHint =>
      'I can search across all your past conversations';

  @override
  String get askAuraSuggestion1 => 'What did we decide about pricing?';

  @override
  String get askAuraSuggestion2 => 'What are my pending action items?';

  @override
  String get askAuraSuggestion3 => 'Summarize last week\'s meetings';

  @override
  String get digestTitle => 'Weekly Digest';

  @override
  String get digestSubtitle => 'Your week at a glance';

  @override
  String get digestMeetings => 'Meetings';

  @override
  String get digestTimeSpent => 'Time Spent';

  @override
  String get digestTopTopics => 'Top Topics';

  @override
  String get digestActionItems => 'Action Items';

  @override
  String get digestCompleted => 'Completed';

  @override
  String get digestPending => 'Pending';

  @override
  String get digestEmpty => 'No meetings this week';

  @override
  String get digestEmptyHint =>
      'Start recording meetings to see your weekly summary';

  @override
  String get onboardingWelcome => 'Welcome to Aura Meet';

  @override
  String get onboardingWelcomeDesc =>
      'Your AI-powered meeting copilot that transcribes, analyzes, and learns from every conversation.';

  @override
  String get onboardingLanguage => 'Choose Your Language';

  @override
  String get onboardingLanguageDesc =>
      'Select the language for the app interface and transcription.';

  @override
  String get onboardingMic => 'Microphone Access';

  @override
  String get onboardingMicDesc =>
      'Aura needs microphone access to transcribe your meetings in real-time.';

  @override
  String get onboardingMicAllow => 'Allow Microphone';

  @override
  String get onboardingReady => 'You\'re All Set!';

  @override
  String get onboardingReadyDesc =>
      'Start your first meeting and let Aura do the rest.';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDone => 'Done';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonCopied => 'Copied to clipboard';

  @override
  String get paywallWelcome => 'Welcome to Aura Pro!';

  @override
  String paywallSave(String amount) {
    return 'Save $amount%';
  }

  @override
  String get paywallRestoring => 'Restoring...';

  @override
  String get paywallSuccessRestore => '✅ Purchases restored!';

  @override
  String get paywallNoRestore => 'No previous purchases found';

  @override
  String get paywallFeatUnlimited => 'Unlimited';

  @override
  String get paywallFeatForever => 'Forever';

  @override
  String get paywallFeatAll => 'All';

  @override
  String get paywallFeatMeetings => 'Meetings per week';

  @override
  String get paywallFeatHistory => 'Meeting history';

  @override
  String get paywallFeatInsights => 'Insights per meeting';

  @override
  String get paywallFeatChat => 'Ask Aura (AI chat)';

  @override
  String get paywallFeatDigest => 'Weekly Digest';

  @override
  String get paywallFeatExport => 'Export & share';

  @override
  String get paywallFeatBriefing => 'Pre-Meeting Briefing';
}
