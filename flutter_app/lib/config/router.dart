import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Hidden for launch — Sprint 2
// import 'package:meetmind/features/ask_aura/ask_aura_screen.dart';
import 'package:meetmind/features/auth/forgot_password_screen.dart';
import 'package:meetmind/features/auth/login_screen.dart';
// Hidden for launch — Sprint 3
// import 'package:meetmind/features/digest/weekly_digest_screen.dart';
import 'package:meetmind/features/history/history_screen.dart';
import 'package:meetmind/features/history/meeting_detail_screen.dart';
import 'package:meetmind/features/home/home_screen.dart';
import 'package:meetmind/features/meeting/meeting_screen.dart';
import 'package:meetmind/features/onboarding/onboarding_screen.dart';
import 'package:meetmind/features/settings/legal_screen.dart';
import 'package:meetmind/features/settings/settings_screen.dart';
import 'package:meetmind/features/splash/splash_screen.dart';
import 'package:meetmind/features/subscription/paywall_screen.dart';
import 'package:meetmind/providers/auth_provider.dart';

/// Routes that do NOT require authentication.
const _publicPaths = {'/login', '/onboarding', '/splash', '/forgot-password'};

/// Build the app router with auth redirect guard.
GoRouter buildRouter(WidgetRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      final path = state.uri.path;

      // Allow public routes and legal pages always
      if (_publicPaths.contains(path) || path.startsWith('/legal')) {
        return null;
      }

      // If still loading auth state, don't redirect yet
      if (authState.isLoading) return null;

      // Guest mode — allow access to all routes (Apple 5.1.1 compliance)
      if (authState.isGuest) return null;

      // Not authenticated → send to login
      if (!authState.isAuthenticated) return '/login';

      return null; // Allow navigation
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
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
      // Hidden for launch — Ask Aura (Sprint 2) & Weekly Digest (Sprint 3)
      // GoRoute(
      //   path: '/ask-aura',
      //   name: 'ask-aura',
      //   builder: (context, state) => const AskAuraScreen(),
      // ),
      // GoRoute(
      //   path: '/digest',
      //   name: 'digest',
      //   builder: (context, state) => const WeeklyDigestScreen(),
      // ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
}
