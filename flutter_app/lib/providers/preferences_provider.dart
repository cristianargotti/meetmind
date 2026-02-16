import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meetmind/services/user_preferences.dart';

/// Preferences state exposed to the UI.
class PreferencesState {
  const PreferencesState({
    required this.locale,
    required this.transcriptionLanguage,
    required this.themeMode,
    required this.audioQuality,
    required this.notificationsEnabled,
    required this.hapticFeedback,
  });

  final AppLocale locale;
  final TranscriptionLanguage transcriptionLanguage;
  final ThemeMode themeMode;
  final AudioQuality audioQuality;
  final bool notificationsEnabled;
  final bool hapticFeedback;

  PreferencesState copyWith({
    AppLocale? locale,
    TranscriptionLanguage? transcriptionLanguage,
    ThemeMode? themeMode,
    AudioQuality? audioQuality,
    bool? notificationsEnabled,
    bool? hapticFeedback,
  }) {
    return PreferencesState(
      locale: locale ?? this.locale,
      transcriptionLanguage:
          transcriptionLanguage ?? this.transcriptionLanguage,
      themeMode: themeMode ?? this.themeMode,
      audioQuality: audioQuality ?? this.audioQuality,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    );
  }
}

/// Notifier that wraps UserPreferences and exposes reactive state.
class PreferencesNotifier extends StateNotifier<PreferencesState> {
  PreferencesNotifier()
      : super(
          PreferencesState(
            locale: UserPreferences.instance.locale,
            transcriptionLanguage:
                UserPreferences.instance.transcriptionLanguage,
            themeMode: _parseThemeMode(UserPreferences.instance.themeMode),
            audioQuality: UserPreferences.instance.audioQuality,
            notificationsEnabled:
                UserPreferences.instance.notificationsEnabled,
            hapticFeedback: UserPreferences.instance.hapticFeedback,
          ),
        ) {
    _sub = UserPreferences.instance.onChange.listen((_) => _refresh());
  }

  StreamSubscription<void>? _sub;

  void _refresh() {
    state = PreferencesState(
      locale: UserPreferences.instance.locale,
      transcriptionLanguage: UserPreferences.instance.transcriptionLanguage,
      themeMode: _parseThemeMode(UserPreferences.instance.themeMode),
      audioQuality: UserPreferences.instance.audioQuality,
      notificationsEnabled: UserPreferences.instance.notificationsEnabled,
      hapticFeedback: UserPreferences.instance.hapticFeedback,
    );
  }

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  /// Update UI locale.
  Future<void> setLocale(AppLocale locale) async {
    await UserPreferences.instance.setLocale(locale);
  }

  /// Update transcription language.
  Future<void> setTranscriptionLanguage(TranscriptionLanguage lang) async {
    await UserPreferences.instance.setTranscriptionLanguage(lang);
  }

  /// Update theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    final String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
      case ThemeMode.system:
        modeStr = 'system';
      case ThemeMode.dark:
        modeStr = 'dark';
    }
    await UserPreferences.instance.setThemeMode(modeStr);
  }

  /// Update audio quality.
  Future<void> setAudioQuality(AudioQuality quality) async {
    await UserPreferences.instance.setAudioQuality(quality);
  }

  /// Toggle notifications.
  Future<void> setNotificationsEnabled(bool value) async {
    await UserPreferences.instance.setNotificationsEnabled(value);
  }

  /// Toggle haptic feedback.
  Future<void> setHapticFeedback(bool value) async {
    await UserPreferences.instance.setHapticFeedback(value);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Main preferences provider.
final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, PreferencesState>(
  (ref) => PreferencesNotifier(),
);

/// Convenience: current locale.
final localeProvider = Provider<Locale>(
  (ref) => ref.watch(preferencesProvider).locale.toLocale(),
);

/// Convenience: current theme mode.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(preferencesProvider).themeMode,
);

/// Convenience: current transcription language code.
final transcriptionLanguageProvider = Provider<String>(
  (ref) => ref.watch(preferencesProvider).transcriptionLanguage.code,
);

/// Convenience: current audio quality.
final audioQualityProvider = Provider<AudioQuality>(
  (ref) => ref.watch(preferencesProvider).audioQuality,
);
