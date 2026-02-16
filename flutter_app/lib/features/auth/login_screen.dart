import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Login screen — Google + Apple Sign-In.
///
/// This is the first screen users see if not authenticated.
/// Clean, minimal design with the Aura Meet logo and two auth buttons.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    // Redirect to home if already authenticated
    if (authState.isAuthenticated && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
    }

    return Scaffold(
      backgroundColor: MeetMindTheme.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 100,
                  height: 100,
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 24),

              // Title
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              // Tagline
              Text(
                l10n.appTagline,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ).animate().fadeIn(delay: 300.ms),

              const Spacer(flex: 2),

              // Error message
              if (authState.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Google Sign-In button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () => _handleGoogleSignIn(context, ref),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(l10n.loginWithGoogle),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 12),

              // Apple Sign-In button (iOS only)
              if (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => _handleAppleSignIn(context, ref),
                    icon: const Icon(Icons.apple, size: 24),
                    label: Text(l10n.loginWithApple),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Skip / Continue without account
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).skipLogin();
                  if (context.mounted) context.go('/');
                },
                child: Text(
                  l10n.loginSkip,
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ).animate().fadeIn(delay: 600.ms),

              // Loading indicator
              if (authState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),

              const Spacer(),

              // Legal links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.push('/legal/privacy'),
                    child: Text(
                      l10n.legalPrivacyPolicy,
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                  const Text(
                    '•',
                    style: TextStyle(color: Colors.white12),
                  ),
                  TextButton(
                    onPressed: () => context.push('/legal/terms'),
                    child: Text(
                      l10n.legalTermsOfService,
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Google Sign-In flow.
  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();

      if (account == null) return; // User cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        _showError(context, 'Google sign-in failed: no id_token received');
        return;
      }

      await ref.read(authProvider.notifier).login(
        provider: 'google',
        idToken: idToken,
        name: account.displayName,
      );

      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Google sign-in error: $e');
      }
    }
  }

  /// Apple Sign-In flow.
  Future<void> _handleAppleSignIn(BuildContext context, WidgetRef ref) async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        _showError(context, 'Apple sign-in failed: no identity token');
        return;
      }

      // Apple only sends name on first login
      String? name;
      if (credential.givenName != null) {
        name = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
            .trim();
      }

      await ref.read(authProvider.notifier).login(
        provider: 'apple',
        idToken: idToken,
        name: name,
      );

      if (context.mounted) {
        context.go('/');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (context.mounted) {
        _showError(context, 'Apple sign-in error: ${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Apple sign-in error: $e');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
      ),
    );
  }

  /// Generate a random nonce string for Apple Sign-In security.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
