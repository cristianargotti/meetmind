import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/config/app_config.dart';
import 'package:meetmind/config/router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/services/notification_service.dart';
import 'package:meetmind/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await NotificationService.instance.initialize();
  await SubscriptionService.instance.initialize();
  runApp(const ProviderScope(child: MeetMindApp()));
}

class MeetMindApp extends StatelessWidget {
  const MeetMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeetMind',
      debugShowCheckedModeBanner: false,
      theme: MeetMindTheme.light,
      darkTheme: MeetMindTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
