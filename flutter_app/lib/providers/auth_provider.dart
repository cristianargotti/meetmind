import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetmind/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth state — user profile + authentication status.
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.isGuest = false,
    this.user,
    this.error,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final bool isGuest;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isGuest,
    Map<String, dynamic>? user,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isGuest: isGuest ?? this.isGuest,
      user: user ?? this.user,
      error: error,
    );
  }

  /// User display name.
  String get name => user?['name'] as String? ?? '';

  /// User email.
  String get email => user?['email'] as String? ?? '';

  /// User avatar URL.
  String get avatarUrl => user?['avatar_url'] as String? ?? '';
}

/// Auth notifier — manages authentication state.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final AuthService _auth = AuthService.instance;

  /// Initialize auth state from stored tokens.
  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    try {
      await _auth.init();
      // Check if user previously skipped login
      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getBool('auth_skipped_login') ?? false;
      state = AuthState(
        isAuthenticated: _auth.isAuthenticated,
        isLoading: false,
        isGuest: skipped && !_auth.isAuthenticated,
        user: _auth.user,
      );
    } catch (e) {
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Skip login — allow guest access.
  Future<void> skipLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth_skipped_login', true);
    state = const AuthState(
      isAuthenticated: false,
      isLoading: false,
      isGuest: true,
    );
  }

  /// Login with Google or Apple.
  Future<void> login({
    required String provider,
    required String idToken,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _auth.login(
        provider: provider,
        idToken: idToken,
        name: name,
      );
      state = AuthState(isAuthenticated: true, isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Register with email and password.
  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _auth.register(
        email: email,
        password: password,
        name: name,
      );
      state = AuthState(isAuthenticated: true, isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Login with email and password.
  Future<void> emailLogin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _auth.emailLogin(email: email, password: password);
      state = AuthState(isAuthenticated: true, isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Logout.
  Future<void> logout() async {
    await _auth.logout();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  /// Delete account and logout.
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      await _auth.deleteAccount();
      state = const AuthState(isAuthenticated: false, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Auth state provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier();
  notifier.init();
  return notifier;
});

/// Convenience provider — is user logged in?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
