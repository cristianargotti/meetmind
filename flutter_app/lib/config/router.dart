import 'package:go_router/go_router.dart';

import 'package:meetmind/features/ask_aura/ask_aura_screen.dart';
import 'package:meetmind/features/auth/login_screen.dart';
import 'package:meetmind/features/digest/weekly_digest_screen.dart';
import 'package:meetmind/features/history/history_screen.dart';
import 'package:meetmind/features/history/meeting_detail_screen.dart';
import 'package:meetmind/features/home/home_screen.dart';
import 'package:meetmind/features/meeting/meeting_screen.dart';
import 'package:meetmind/features/onboarding/onboarding_screen.dart';
import 'package:meetmind/features/settings/legal_screen.dart';
import 'package:meetmind/features/settings/settings_screen.dart';
import 'package:meetmind/features/subscription/paywall_screen.dart';

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
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
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
      path: '/meeting/:id',
      name: 'meeting-detail',
      builder: (context, state) =>
          MeetingDetailScreen(meetingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/paywall',
      name: 'paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/legal/:type',
      name: 'legal',
      builder: (context, state) =>
          LegalScreen(type: state.pathParameters['type'] ?? 'privacy'),
    ),
    GoRoute(
      path: '/ask-aura',
      name: 'ask-aura',
      builder: (context, state) => const AskAuraScreen(),
    ),
    GoRoute(
      path: '/digest',
      name: 'digest',
      builder: (context, state) => const WeeklyDigestScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
  ],
);
