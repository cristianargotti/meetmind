import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/providers/auth_provider.dart';
import 'package:meetmind/services/user_preferences.dart';

/// Animated splash screen — premium first impression.
///
/// Shows a brief, cinematic logo reveal while checking auth state.
/// Routes to: Onboarding (first launch) → Login (no auth) → Home (authenticated).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Let the animation play for at least 2.5s
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    if (!mounted || _navigated) return;
    _navigated = true;

    // Check if user has completed onboarding using the correct key
    // (UserPreferences uses 'pref_onboarding_complete' internally)
    final hasOnboarded = UserPreferences.instance.onboardingComplete;

    if (!mounted) return;

    if (!hasOnboarded) {
      context.go('/onboarding');
      return;
    }

    // Check auth state
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0A1E), // Deep purple-black
              MeetMindTheme.darkBg,
              Color(0xFF0A0F1A), // Deep blue-black
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Ambient glow behind logo
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MeetMindTheme.primary.withValues(alpha: 0.15),
                      MeetMindTheme.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
                  .animate()
                  .scaleXY(
                    begin: 0.5,
                    end: 1.2,
                    duration: 2000.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeIn(duration: 800.ms),
            ),

            // Logo + text
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 100,
                      height: 100,
                    ),
                  )
                      .animate()
                      .scaleXY(
                        begin: 0.3,
                        end: 1.0,
                        duration: 800.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 24),

                  // App name
                  const Text(
                    'Aura Meet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                  const SizedBox(height: 8),

                  // Tagline with shimmer
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        MeetMindTheme.primaryLight,
                        MeetMindTheme.accent,
                        MeetMindTheme.primaryLight,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Your AI meeting copilot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 600.ms)
                      .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),
                ],
              ),
            ),

            // Bottom loading indicator
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MeetMindTheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              ).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }
}
