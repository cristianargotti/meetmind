import 'dart:async';

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
import 'package:meetmind/services/subscription_service.dart';
import 'package:meetmind/services/user_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error boundary — catches uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // TODO: Send to Sentry/Crashlytics when integrated
    if (kDebugMode) {
      debugPrint('🔴 FlutterError: ${details.exception}');
      debugPrint('${details.stack}');
    }
  };

  // Catch async errors not handled by Flutter framework
  runZonedGuarded(() async {
    await AppConfig.initialize();
    await UserPreferences.initialize();
    await NotificationService.instance.initialize();
    await SubscriptionService.instance.initialize();
    runApp(const ProviderScope(child: MeetMindApp()));
  }, (Object error, StackTrace stack) {
    // TODO: Send to Sentry/Crashlytics when integrated
    if (kDebugMode) {
      debugPrint('🔴 Uncaught async error: $error');
      debugPrint('$stack');
    }
  });
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
      theme: MeetMindTheme.light,
      darkTheme: MeetMindTheme.dark,
      themeMode: themeMode,
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
