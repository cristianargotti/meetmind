import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Aura Meet'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI meeting copilot'**
  String get appTagline;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get loginWithApple;

  /// No description provided for @loginSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without account'**
  String get loginSkip;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Aura Meet'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI meeting companion'**
  String get homeSubtitle;

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// No description provided for @homeInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get homeInsights;

  /// No description provided for @homeActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get homeActions;

  /// No description provided for @homeRecentMeetings.
  ///
  /// In en, this message translates to:
  /// **'Recent Meetings'**
  String get homeRecentMeetings;

  /// No description provided for @homeNoMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings yet'**
  String get homeNoMeetings;

  /// No description provided for @homeNoMeetingsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to start your first meeting'**
  String get homeNoMeetingsHint;

  /// No description provided for @homeStartMeeting.
  ///
  /// In en, this message translates to:
  /// **'Start a Meeting'**
  String get homeStartMeeting;

  /// No description provided for @homeMeetingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Meeting in Progress'**
  String get homeMeetingInProgress;

  /// No description provided for @homeAiListening.
  ///
  /// In en, this message translates to:
  /// **'AI is listening and analyzing...'**
  String get homeAiListening;

  /// No description provided for @homeTranscribeRealtime.
  ///
  /// In en, this message translates to:
  /// **'Aura will transcribe and analyze in real-time'**
  String get homeTranscribeRealtime;

  /// No description provided for @homeLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get homeLive;

  /// No description provided for @meetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingTitle;

  /// No description provided for @meetingRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get meetingRecording;

  /// No description provided for @meetingPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get meetingPaused;

  /// No description provided for @meetingStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get meetingStopped;

  /// No description provided for @meetingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get meetingStart;

  /// No description provided for @meetingPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get meetingPause;

  /// No description provided for @meetingResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get meetingResume;

  /// No description provided for @meetingStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get meetingStop;

  /// No description provided for @meetingTranscript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get meetingTranscript;

  /// No description provided for @meetingInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get meetingInsights;

  /// No description provided for @meetingSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get meetingSummary;

  /// No description provided for @meetingNoTranscript.
  ///
  /// In en, this message translates to:
  /// **'Waiting for audio...'**
  String get meetingNoTranscript;

  /// No description provided for @meetingNoInsights.
  ///
  /// In en, this message translates to:
  /// **'No insights yet'**
  String get meetingNoInsights;

  /// No description provided for @meetingCopySummary.
  ///
  /// In en, this message translates to:
  /// **'Copy Summary'**
  String get meetingCopySummary;

  /// No description provided for @meetingSummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Summary copied to clipboard'**
  String get meetingSummaryCopied;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No meeting history'**
  String get historyEmpty;

  /// No description provided for @historyEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your past meetings will appear here'**
  String get historyEmptyHint;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsUiLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsUiLanguage;

  /// No description provided for @settingsTranscriptionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Transcription Language'**
  String get settingsTranscriptionLanguage;

  /// No description provided for @settingsAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get settingsAutoDetect;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsAudioQuality.
  ///
  /// In en, this message translates to:
  /// **'Recording Quality'**
  String get settingsAudioQuality;

  /// No description provided for @settingsAudioStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsAudioStandard;

  /// No description provided for @settingsAudioHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsAudioHigh;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Meeting Reminders'**
  String get settingsNotificationsEnabled;

  /// No description provided for @settingsHapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get settingsHapticFeedback;

  /// No description provided for @settingsBackendConnection.
  ///
  /// In en, this message translates to:
  /// **'Backend Connection'**
  String get settingsBackendConnection;

  /// No description provided for @settingsProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get settingsProtocol;

  /// No description provided for @settingsHost.
  ///
  /// In en, this message translates to:
  /// **'Host (IP or domain)'**
  String get settingsHost;

  /// No description provided for @settingsHostHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.0.12 or api.aurameet.io'**
  String get settingsHostHint;

  /// No description provided for @settingsPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settingsPort;

  /// No description provided for @settingsPortHint.
  ///
  /// In en, this message translates to:
  /// **'8000'**
  String get settingsPortHint;

  /// No description provided for @settingsResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset Defaults'**
  String get settingsResetDefaults;

  /// No description provided for @settingsBackendUpdated.
  ///
  /// In en, this message translates to:
  /// **'Backend updated: {url}'**
  String settingsBackendUpdated(String url);

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsResetDone;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsAiModels.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get settingsAiModels;

  /// No description provided for @settingsScreening.
  ///
  /// In en, this message translates to:
  /// **'Screening'**
  String get settingsScreening;

  /// No description provided for @settingsAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get settingsAnalysis;

  /// No description provided for @settingsDeepThink.
  ///
  /// In en, this message translates to:
  /// **'Deep Think'**
  String get settingsDeepThink;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get accountSignOutConfirm;

  /// No description provided for @accountDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get accountDeleteAccount;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all your meeting data. This action cannot be undone.'**
  String get accountDeleteConfirmBody;

  /// No description provided for @accountDeleteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get accountDeleteConfirmButton;

  /// No description provided for @accountGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get accountGuestUser;

  /// No description provided for @accountLinkedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get accountLinkedAccounts;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authName;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// No description provided for @authToggleToRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get authToggleToRegister;

  /// No description provided for @authToggleToLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authToggleToLogin;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authFillFields.
  ///
  /// In en, this message translates to:
  /// **'Enter email and password'**
  String get authFillFields;

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionFree;

  /// No description provided for @subscriptionPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get subscriptionPro;

  /// No description provided for @subscriptionTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get subscriptionTeam;

  /// No description provided for @subscriptionBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get subscriptionBusiness;

  /// No description provided for @subscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Active subscription'**
  String get subscriptionActive;

  /// No description provided for @subscriptionFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan — {limit} meetings/week'**
  String subscriptionFreePlan(int limit);

  /// No description provided for @subscriptionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get subscriptionManage;

  /// No description provided for @subscriptionUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get subscriptionUpgrade;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Aura Pro'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI meeting copilot, unleashed'**
  String get paywallSubtitle;

  /// No description provided for @paywallMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallMonthly;

  /// No description provided for @paywallYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallYearly;

  /// No description provided for @paywallSaveBadge.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String paywallSaveBadge(int percent);

  /// No description provided for @paywallStartProMonthly.
  ///
  /// In en, this message translates to:
  /// **'Start Pro — {price}/month'**
  String paywallStartProMonthly(String price);

  /// No description provided for @paywallStartProYearly.
  ///
  /// In en, this message translates to:
  /// **'Start Pro — {price}/year'**
  String paywallStartProYearly(String price);

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get paywallRestore;

  /// No description provided for @paywallRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get paywallRestoreSuccess;

  /// No description provided for @paywallRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'No purchases found to restore'**
  String get paywallRestoreNone;

  /// No description provided for @paywallPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aura Pro! 🎉'**
  String get paywallPurchaseSuccess;

  /// No description provided for @paywallPurchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled'**
  String get paywallPurchaseCancelled;

  /// No description provided for @paywallPurchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed: {error}'**
  String paywallPurchaseError(String error);

  /// No description provided for @paywallFeatureFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get paywallFeatureFree;

  /// No description provided for @paywallFeaturePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get paywallFeaturePro;

  /// No description provided for @paywallFeatureMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get paywallFeatureMeetings;

  /// No description provided for @paywallFeatureMeetingsFreeValue.
  ///
  /// In en, this message translates to:
  /// **'{limit}/week'**
  String paywallFeatureMeetingsFreeValue(int limit);

  /// No description provided for @paywallFeatureMeetingsProValue.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get paywallFeatureMeetingsProValue;

  /// No description provided for @paywallFeatureTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get paywallFeatureTranscription;

  /// No description provided for @paywallFeatureInsights.
  ///
  /// In en, this message translates to:
  /// **'AI Insights'**
  String get paywallFeatureInsights;

  /// No description provided for @paywallFeatureAskAura.
  ///
  /// In en, this message translates to:
  /// **'Ask Aura'**
  String get paywallFeatureAskAura;

  /// No description provided for @paywallFeatureExport.
  ///
  /// In en, this message translates to:
  /// **'Full Export'**
  String get paywallFeatureExport;

  /// No description provided for @paywallFeatureDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly Digest'**
  String get paywallFeatureDigest;

  /// No description provided for @paywallLegal.
  ///
  /// In en, this message translates to:
  /// **'Subscription auto-renews at the price shown above unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account. By subscribing you agree to our Privacy Policy and Terms of Use.'**
  String get paywallLegal;

  /// No description provided for @freeLimitBannerRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} meeting(s) left this week'**
  String freeLimitBannerRemaining(int remaining);

  /// No description provided for @freeLimitBannerReached.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit reached'**
  String get freeLimitBannerReached;

  /// No description provided for @freeLimitBannerUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} / {limit} meetings'**
  String freeLimitBannerUsage(int used, int limit);

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @proGateLocked.
  ///
  /// In en, this message translates to:
  /// **'Pro Feature'**
  String get proGateLocked;

  /// No description provided for @proGateUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get proGateUnlock;

  /// No description provided for @legalPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicy;

  /// No description provided for @legalTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTermsOfService;

  /// No description provided for @legalLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: February 2026'**
  String get legalLastUpdated;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Matters'**
  String get privacyIntro;

  /// No description provided for @privacyIntroDesc.
  ///
  /// In en, this message translates to:
  /// **'Aura Meet is designed with privacy at its core. Here\'s how we handle your data:'**
  String get privacyIntroDesc;

  /// No description provided for @privacyAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'🎙️ Audio Processing'**
  String get privacyAudioTitle;

  /// No description provided for @privacyAudioDesc.
  ///
  /// In en, this message translates to:
  /// **'• Speech-to-text runs ON YOUR DEVICE\n• No audio is ever sent to our servers or stored in the cloud\n• Audio data stays on your device at all times'**
  String get privacyAudioDesc;

  /// No description provided for @privacyDataTitle.
  ///
  /// In en, this message translates to:
  /// **'📝 Meeting Data'**
  String get privacyDataTitle;

  /// No description provided for @privacyDataDesc.
  ///
  /// In en, this message translates to:
  /// **'• Transcripts are sent to our servers for AI analysis only\n• Meeting data is stored securely with encryption at rest\n• You can delete any meeting and its data at any time'**
  String get privacyDataDesc;

  /// No description provided for @privacySubsTitle.
  ///
  /// In en, this message translates to:
  /// **'💳 Subscriptions'**
  String get privacySubsTitle;

  /// No description provided for @privacySubsDesc.
  ///
  /// In en, this message translates to:
  /// **'• We never see or store your payment details\n• Apple/Google handles all payment processing'**
  String get privacySubsDesc;

  /// No description provided for @privacyRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'🔒 Your Rights'**
  String get privacyRightsTitle;

  /// No description provided for @privacyRightsDesc.
  ///
  /// In en, this message translates to:
  /// **'• Request deletion of all your data at any time\n• Export all your meeting data\n• We do not sell your data to third parties\n• We do not use your data for advertising'**
  String get privacyRightsDesc;

  /// No description provided for @privacyContact.
  ///
  /// In en, this message translates to:
  /// **'For privacy inquiries: privacy@aurameet.live'**
  String get privacyContact;

  /// No description provided for @privacyDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get privacyDeleteAccount;

  /// No description provided for @privacyDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This action cannot be undone.'**
  String get privacyDeleteConfirm;

  /// No description provided for @privacyDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get privacyDeleteButton;

  /// No description provided for @termsIntro.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsIntro;

  /// No description provided for @termsIntroDesc.
  ///
  /// In en, this message translates to:
  /// **'By using Aura Meet, you agree to these terms:'**
  String get termsIntroDesc;

  /// No description provided for @termsServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'📱 Service'**
  String get termsServiceTitle;

  /// No description provided for @termsServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'• Aura Meet is an AI-powered meeting assistant\n• We provide transcription, insights, and meeting management\n• Service availability is provided on a best-effort basis\n• Features may change as we improve the product'**
  String get termsServiceDesc;

  /// No description provided for @termsSubsTitle.
  ///
  /// In en, this message translates to:
  /// **'💰 Subscriptions'**
  String get termsSubsTitle;

  /// No description provided for @termsSubsDesc.
  ///
  /// In en, this message translates to:
  /// **'• Free plan: 3 meetings/week with limited features\n• Subscriptions auto-renew unless cancelled\n• Cancel anytime through App Store or Google Play\n• No refunds for partial billing periods'**
  String get termsSubsDesc;

  /// No description provided for @termsUseTitle.
  ///
  /// In en, this message translates to:
  /// **'✅ Acceptable Use'**
  String get termsUseTitle;

  /// No description provided for @termsUseDesc.
  ///
  /// In en, this message translates to:
  /// **'• Use Aura Meet for legitimate meeting assistance\n• Comply with all applicable recording consent laws\n• You are responsible for obtaining consent from meeting participants'**
  String get termsUseDesc;

  /// No description provided for @termsLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'⚖️ Liability'**
  String get termsLiabilityTitle;

  /// No description provided for @termsLiabilityDesc.
  ///
  /// In en, this message translates to:
  /// **'• AI-generated insights may not be 100% accurate\n• We are not liable for decisions made based on AI analysis\n• Service is provided \"as-is\" without warranties'**
  String get termsLiabilityDesc;

  /// No description provided for @termsContact.
  ///
  /// In en, this message translates to:
  /// **'For support: support@aurameet.live'**
  String get termsContact;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version} — Your AI meeting copilot'**
  String aboutVersion(String version);

  /// No description provided for @askAuraTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask Aura'**
  String get askAuraTitle;

  /// No description provided for @askAuraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chat with your meetings'**
  String get askAuraSubtitle;

  /// No description provided for @askAuraPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask about your meetings...'**
  String get askAuraPlaceholder;

  /// No description provided for @askAuraEmpty.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your meetings'**
  String get askAuraEmpty;

  /// No description provided for @askAuraEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'I can search across all your past conversations'**
  String get askAuraEmptyHint;

  /// No description provided for @askAuraSuggestion1.
  ///
  /// In en, this message translates to:
  /// **'What did we decide about pricing?'**
  String get askAuraSuggestion1;

  /// No description provided for @askAuraSuggestion2.
  ///
  /// In en, this message translates to:
  /// **'What are my pending action items?'**
  String get askAuraSuggestion2;

  /// No description provided for @askAuraSuggestion3.
  ///
  /// In en, this message translates to:
  /// **'Summarize last week\'s meetings'**
  String get askAuraSuggestion3;

  /// No description provided for @digestTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Digest'**
  String get digestTitle;

  /// No description provided for @digestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your week at a glance'**
  String get digestSubtitle;

  /// No description provided for @digestMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get digestMeetings;

  /// No description provided for @digestTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Time Spent'**
  String get digestTimeSpent;

  /// No description provided for @digestTopTopics.
  ///
  /// In en, this message translates to:
  /// **'Top Topics'**
  String get digestTopTopics;

  /// No description provided for @digestActionItems.
  ///
  /// In en, this message translates to:
  /// **'Action Items'**
  String get digestActionItems;

  /// No description provided for @digestCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get digestCompleted;

  /// No description provided for @digestPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get digestPending;

  /// No description provided for @digestEmpty.
  ///
  /// In en, this message translates to:
  /// **'No meetings this week'**
  String get digestEmpty;

  /// No description provided for @digestEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Start recording meetings to see your weekly summary'**
  String get digestEmptyHint;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aura Meet'**
  String get onboardingWelcome;

  /// No description provided for @onboardingWelcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Your AI-powered meeting copilot that transcribes, analyzes, and learns from every conversation.'**
  String get onboardingWelcomeDesc;

  /// No description provided for @onboardingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get onboardingLanguage;

  /// No description provided for @onboardingLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Select the language for the app interface and transcription.'**
  String get onboardingLanguageDesc;

  /// No description provided for @onboardingMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone Access'**
  String get onboardingMic;

  /// No description provided for @onboardingMicDesc.
  ///
  /// In en, this message translates to:
  /// **'Aura needs microphone access to transcribe your meetings in real-time.'**
  String get onboardingMicDesc;

  /// No description provided for @onboardingMicAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow Microphone'**
  String get onboardingMicAllow;

  /// No description provided for @onboardingReady.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get onboardingReady;

  /// No description provided for @onboardingReadyDesc.
  ///
  /// In en, this message translates to:
  /// **'Start your first meeting and let Aura do the rest.'**
  String get onboardingReadyDesc;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get commonCopied;

  /// No description provided for @paywallWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aura Pro!'**
  String get paywallWelcome;

  /// No description provided for @paywallSave.
  ///
  /// In en, this message translates to:
  /// **'Save {amount}%'**
  String paywallSave(String amount);

  /// No description provided for @paywallRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get paywallRestoring;

  /// No description provided for @paywallSuccessRestore.
  ///
  /// In en, this message translates to:
  /// **'✅ Purchases restored!'**
  String get paywallSuccessRestore;

  /// No description provided for @paywallNoRestore.
  ///
  /// In en, this message translates to:
  /// **'No previous purchases found'**
  String get paywallNoRestore;

  /// No description provided for @paywallFeatUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get paywallFeatUnlimited;

  /// No description provided for @paywallFeatForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get paywallFeatForever;

  /// No description provided for @paywallFeatAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get paywallFeatAll;

  /// No description provided for @paywallFeatMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings per week'**
  String get paywallFeatMeetings;

  /// No description provided for @paywallFeatHistory.
  ///
  /// In en, this message translates to:
  /// **'Meeting history'**
  String get paywallFeatHistory;

  /// No description provided for @paywallFeatInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights per meeting'**
  String get paywallFeatInsights;

  /// No description provided for @paywallFeatChat.
  ///
  /// In en, this message translates to:
  /// **'Ask Aura (AI chat)'**
  String get paywallFeatChat;

  /// No description provided for @paywallFeatDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly Digest'**
  String get paywallFeatDigest;

  /// No description provided for @paywallFeatExport.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get paywallFeatExport;

  /// No description provided for @paywallFeatBriefing.
  ///
  /// In en, this message translates to:
  /// **'Pre-Meeting Briefing'**
  String get paywallFeatBriefing;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get forgotPasswordDescription;

  /// No description provided for @forgotPasswordEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get forgotPasswordEnterEmail;

  /// No description provided for @forgotPasswordSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgotPasswordSendLink;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent!'**
  String get forgotPasswordSent;

  /// No description provided for @forgotPasswordCheckInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your email inbox for a link to reset your password. It may take a few minutes.'**
  String get forgotPasswordCheckInbox;

  /// No description provided for @forgotPasswordBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get forgotPasswordBackToLogin;

  /// No description provided for @forgotPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get forgotPasswordError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
