import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/config/router.dart';
import 'package:meetmind/config/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
