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

/// Login screen — Email/Password + Google + Apple Sign-In.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 80,
                  height: 80,
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 16),

              // Title
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 4),

              // Tagline
              Text(
                l10n.appTagline,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              // Error message
              if (authState.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ─── Email/Password Form ────────────────────
              if (_isRegisterMode)
                _buildTextField(
                  controller: _nameController,
                  hint: l10n.authName,
                  icon: Icons.person_outline,
                ).animate().fadeIn(duration: 200.ms),

              if (_isRegisterMode) const SizedBox(height: 12),

              _buildTextField(
                controller: _emailController,
                hint: l10n.authEmail,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 12),

              _buildTextField(
                controller: _passwordController,
                hint: l10n.authPassword,
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: authState.isLoading
                      ? null
                      : () => _handleEmailAuth(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeetMindTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                      _isRegisterMode ? l10n.authCreateAccount : l10n.authSignIn),
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              // Toggle register/login
              TextButton(
                onPressed: () =>
                    setState(() => _isRegisterMode = !_isRegisterMode),
                child: Text(
                  _isRegisterMode
                      ? l10n.authToggleToLogin
                      : l10n.authToggleToRegister,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),

              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  Expanded(
                      child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('o', style: TextStyle(color: Colors.white38)),
                  ),
                  Expanded(
                      child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                ],
              ),

              const SizedBox(height: 16),

              // Google Sign-In button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () => _handleGoogleSignIn(context),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(l10n.loginWithGoogle),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 12),

              // Apple Sign-In button
              if (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => _handleAppleSignIn(context),
                    icon: const Icon(Icons.apple, size: 24),
                    label: Text(l10n.loginWithApple),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side:
                          BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),

              // Loading indicator
              if (authState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),

              const SizedBox(height: 24),

              // Legal links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.push('/legal/privacy'),
                    child: Text(
                      l10n.legalPrivacyPolicy,
                      style:
                          const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                  const Text('•', style: TextStyle(color: Colors.white12)),
                  TextButton(
                    onPressed: () => context.push('/legal/terms'),
                    child: Text(
                      l10n.legalTermsOfService,
                      style:
                          const TextStyle(color: Colors.white24, fontSize: 12),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MeetMindTheme.accent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// Email/password auth flow.
  Future<void> _handleEmailAuth(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError(context, l10n.authFillFields);
      return;
    }

    if (_isRegisterMode && password.length < 6) {
      _showError(context, l10n.authPasswordMinLength);
      return;
    }

    try {
      if (_isRegisterMode) {
        await ref.read(authProvider.notifier).register(
              email: email,
              password: password,
              name: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : null,
            );
      } else {
        await ref.read(authProvider.notifier).emailLogin(
              email: email,
              password: password,
            );
      }

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) _showError(context, '$e');
    }
  }

  /// Google Sign-In flow.
  Future<void> _handleGoogleSignIn(BuildContext context) async {
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

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) _showError(context, 'Google sign-in error: $e');
    }
  }

  /// Apple Sign-In flow.
  Future<void> _handleAppleSignIn(BuildContext context) async {
    try {
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

      if (mounted) context.go('/');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (mounted) _showError(context, 'Apple sign-in error: ${e.message}');
    } catch (e) {
      if (mounted) _showError(context, 'Apple sign-in error: $e');
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

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
