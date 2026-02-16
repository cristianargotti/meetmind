import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app locales.
enum AppLocale {
  en('en', 'English', '🇺🇸'),
  es('es', 'Español', '🇨🇴'),
  pt('pt', 'Português', '🇧🇷');

  const AppLocale(this.code, this.displayName, this.flag);
  final String code;
  final String displayName;
  final String flag;

  /// Get locale from code string.
  static AppLocale fromCode(String code) {
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.en,
    );
  }

  /// Convert to Flutter Locale.
  Locale toLocale() => Locale(code);
}

/// Supported transcription languages.
enum TranscriptionLanguage {
  auto('auto', 'Auto-detect', '🔄'),
  en('en', 'English', '🇺🇸'),
  es('es', 'Español', '🇨🇴'),
  pt('pt', 'Português', '🇧🇷');

  const TranscriptionLanguage(this.code, this.displayName, this.icon);
  final String code;
  final String displayName;
  final String icon;

  static TranscriptionLanguage fromCode(String code) {
    return TranscriptionLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => TranscriptionLanguage.auto,
    );
  }
}

/// Audio recording quality.
enum AudioQuality {
  standard('standard', '16kHz mono'),
  high('high', '44.1kHz stereo');

  const AudioQuality(this.code, this.description);
  final String code;
  final String description;

  static AudioQuality fromCode(String code) {
    return AudioQuality.values.firstWhere(
      (q) => q.code == code,
      orElse: () => AudioQuality.standard,
    );
  }
}

/// Central user preferences service.
///
/// Manages all configurable settings persisted via SharedPreferences:
/// - UI language (locale)
/// - Transcription language
/// - Theme mode
/// - Audio quality
/// - Notifications
/// - Haptic feedback
/// - Onboarding completion
class UserPreferences {
  UserPreferences._({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  // ─── Keys ─────────────────────────────────
  static const String _keyLocale = 'pref_locale';
  static const String _keyTranscriptionLang = 'pref_transcription_lang';
  static const String _keyThemeMode = 'pref_theme_mode';
  static const String _keyAudioQuality = 'pref_audio_quality';
  static const String _keyNotifications = 'pref_notifications';
  static const String _keyHapticFeedback = 'pref_haptic_feedback';
  static const String _keyOnboardingComplete = 'pref_onboarding_complete';

  // ─── Singleton ────────────────────────────
  static UserPreferences? _instance;

  /// Initialize from SharedPreferences. Call in main() before runApp.
  static Future<UserPreferences> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _instance = UserPreferences._(prefs: prefs);
    return _instance!;
  }

  /// Get the singleton instance. Throws if not initialized.
  static UserPreferences get instance {
    if (_instance == null) {
      throw StateError(
        'UserPreferences.initialize() must be called before use',
      );
    }
    return _instance!;
  }

  // ─── Stream for reactive updates ──────────
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  /// Stream that emits when any preference changes.
  Stream<void> get onChange => _changeController.stream;

  void _notifyChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  // ─── Locale ───────────────────────────────

  /// Current UI locale.
  AppLocale get locale {
    final String? code = _prefs.getString(_keyLocale);
    if (code == null) {
      // Default to device locale if supported, otherwise English.
      final String deviceLocale =
          PlatformDispatcher.instance.locale.languageCode;
      final bool isSupported = AppLocale.values.any(
        (l) => l.code == deviceLocale,
      );
      return isSupported ? AppLocale.fromCode(deviceLocale) : AppLocale.en;
    }
    return AppLocale.fromCode(code);
  }

  /// Set UI locale.
  Future<void> setLocale(AppLocale value) async {
    await _prefs.setString(_keyLocale, value.code);
    _notifyChange();
  }

  // ─── Transcription Language ───────────────

  /// Current transcription language.
  TranscriptionLanguage get transcriptionLanguage {
    final String? code = _prefs.getString(_keyTranscriptionLang);
    return code != null
        ? TranscriptionLanguage.fromCode(code)
        : TranscriptionLanguage.auto;
  }

  /// Set transcription language.
  Future<void> setTranscriptionLanguage(TranscriptionLanguage value) async {
    await _prefs.setString(_keyTranscriptionLang, value.code);
    _notifyChange();
  }

  // ─── Theme Mode ───────────────────────────

  /// Current theme mode (dark/light/system).
  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'dark';

  /// Set theme mode.
  Future<void> setThemeMode(String value) async {
    await _prefs.setString(_keyThemeMode, value);
    _notifyChange();
  }

  // ─── Audio Quality ────────────────────────

  /// Current audio quality.
  AudioQuality get audioQuality {
    final String? code = _prefs.getString(_keyAudioQuality);
    return code != null
        ? AudioQuality.fromCode(code)
        : AudioQuality.standard;
  }

  /// Set audio quality.
  Future<void> setAudioQuality(AudioQuality value) async {
    await _prefs.setString(_keyAudioQuality, value.code);
    _notifyChange();
  }

  // ─── Notifications ────────────────────────

  /// Whether notifications are enabled.
  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotifications) ?? true;

  /// Set notifications enabled.
  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_keyNotifications, value);
    _notifyChange();
  }

  // ─── Haptic Feedback ──────────────────────

  /// Whether haptic feedback is enabled.
  bool get hapticFeedback => _prefs.getBool(_keyHapticFeedback) ?? true;

  /// Set haptic feedback enabled.
  Future<void> setHapticFeedback(bool value) async {
    await _prefs.setBool(_keyHapticFeedback, value);
    _notifyChange();
  }

  // ─── Onboarding ───────────────────────────

  /// Whether onboarding has been completed.
  bool get onboardingComplete =>
      _prefs.getBool(_keyOnboardingComplete) ?? false;

  /// Mark onboarding as complete.
  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_keyOnboardingComplete, value);
    _notifyChange();
  }

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}
