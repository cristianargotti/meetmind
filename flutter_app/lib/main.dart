import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/config/app_config.dart';
import 'package:meetmind/config/router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/preferences_provider.dart';
import 'package:meetmind/services/notification_service.dart';
import 'package:meetmind/services/stt_service.dart';
import 'package:meetmind/services/subscription_service.dart';
import 'package:meetmind/services/user_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry DSN — injected via --dart-define=SENTRY_DSN=...
const _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services before Sentry
  await AppConfig.initialize();
  await UserPreferences.initialize();
  await NotificationService.instance.initialize();
  await SubscriptionService.instance.initialize();

  // Initialize Apple STT in background (fire-and-forget)
  _initializeStt();

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.environment = kDebugMode ? 'development' : 'production';
        options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
        options.attachScreenshot = true;
        options.sendDefaultPii = false;
        options.diagnosticLevel = SentryLevel.warning;
      },
      appRunner: () =>
          runApp(const ProviderScope(child: MeetMindApp())),
    );
  } else {
    // No DSN — fallback to manual error logging (dev/CI)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('🔴 FlutterError: ${details.exception}');
      }
    };
    runApp(const ProviderScope(child: MeetMindApp()));
  }
}

/// Initialize Apple's on-device speech recognition.
///
/// No model download needed — Apple's speech engine is built into iOS.
/// This just checks availability and requests permission.
Future<void> _initializeStt() async {
  try {
    final String lang = UserPreferences.instance.transcriptionLanguage.code;

    final SttService stt = SttService.instance;
    final bool available = await stt.initialize(language: lang);
    debugPrint('[SttInit] ${available ? "Ready" : "Not available"} (lang=$lang)');
  } catch (e) {
    // Never crash the app — STT just won't be available
    debugPrint('[SttInit] Failed (non-fatal): $e');
  }
}

class MeetMindApp extends ConsumerWidget {
  const MeetMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Aura Meet',
      debugShowCheckedModeBanner: false,
      theme: MeetMindTheme.dark,
      darkTheme: MeetMindTheme.dark,
      themeMode: ThemeMode.dark, // Dark-only for launch; light theme Sprint 2
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildRouter(ref),
    );
  }
}
