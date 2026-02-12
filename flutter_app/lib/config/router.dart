import 'package:go_router/go_router.dart';

import 'package:meetmind/features/history/history_screen.dart';
import 'package:meetmind/features/home/home_screen.dart';
import 'package:meetmind/features/meeting/meeting_screen.dart';
import 'package:meetmind/features/settings/settings_screen.dart';
import 'package:meetmind/features/setup/model_download_screen.dart';

/// App router configuration using GoRouter.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/meeting',
      name: 'meeting',
      builder: (context, state) => const MeetingScreen(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/model-setup',
      name: 'model-setup',
      builder: (context, state) => const ModelDownloadScreen(),
    ),
  ],
);
