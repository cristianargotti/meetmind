import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:meetmind/config/app_config.dart';
import 'package:meetmind/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service — handles OAuth login, token management, and logout.
///
/// Communicates with backend endpoints:
///   POST /api/auth/login    — exchange provider id_token for JWT
///   POST /api/auth/refresh  — refresh expired access token
///   GET  /api/auth/me       — get current user profile
///   DELETE /api/auth/account — delete user account
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userKey = 'auth_user';
  static const _migratedKey = 'auth_tokens_migrated';

  /// Secure storage for JWT tokens (iOS Keychain / Android EncryptedSharedPrefs).
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _accessToken != null;

  /// Current user profile (null if not authenticated).
  Map<String, dynamic>? get user => _user;

  /// Current access token for API calls.
  String? get accessToken => _accessToken;

  /// Build base URL from AppConfig.
  ///
  /// Omits port when it's the default for the scheme (443 for HTTPS, 80 for HTTP)
  /// to avoid issues with reverse proxies and CDNs.
  String get _baseUrl {
    final config = AppConfig.instance;
    final scheme = config.protocol == 'wss' ? 'https' : 'http';
    final isDefaultPort = (scheme == 'https' && config.port == 443) ||
        (scheme == 'http' && config.port == 80);
    return isDefaultPort
        ? '$scheme://${config.host}'
        : '$scheme://${config.host}:${config.port}';
  }

  /// Initialize from stored tokens (call on app startup).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate tokens from SharedPreferences to SecureStorage (one-time)
    if (prefs.getBool(_migratedKey) != true) {
      final oldAccess = prefs.getString(_accessTokenKey);
      final oldRefresh = prefs.getString(_refreshTokenKey);
      if (oldAccess != null) {
        await _secureStorage.write(key: _accessTokenKey, value: oldAccess);
        await prefs.remove(_accessTokenKey);
      }
      if (oldRefresh != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: oldRefresh);
        await prefs.remove(_refreshTokenKey);
      }
      await prefs.setBool(_migratedKey, true);
    }

    _accessToken = await _secureStorage.read(key: _accessTokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);

    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = jsonDecode(userJson) as Map<String, dynamic>;
    }

    // Try refreshing if we have a refresh token but no valid access token
    if (_refreshToken != null) {
      try {
        await refreshToken();
        // Refresh user profile to get latest name, avatar, etc.
        try {
          await getProfile();
        } catch (_) {
          // Profile fetch failed — keep cached user data
        }

        // Identify in RevenueCat + check for override accounts
        if (_user != null && _user!['id'] != null) {
          await SubscriptionService.instance.logIn(_user!['id'].toString());
          SubscriptionService.instance.grantProOverride(
            _user!['email'] as String?,
          );
        }
      } catch (_) {
        // Refresh failed — clear everything
        await logout();
      }
    }
  }

  /// Login with a Google or Apple id_token.
  Future<Map<String, dynamic>> login({
    required String provider,
    required String idToken,
    String? name,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'id_token': idToken,
        if (name != null) 'name': name, // ignore: use_null_aware_elements
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _user = data['user'] as Map<String, dynamic>;

    await _persistTokens();

    // Identify in RevenueCat + check for override accounts
    if (_user != null && _user!['id'] != null) {
      await SubscriptionService.instance.logIn(_user!['id'].toString());
      SubscriptionService.instance.grantProOverride(
        _user!['email'] as String?,
      );
    }

    return _user!;
  }

  /// Register with email and password.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null) 'name': name, // ignore: use_null_aware_elements
      }),
    );

    if (response.statusCode == 409) {
      throw Exception('Email already registered');
    }
    if (response.statusCode != 200) {
      throw Exception('Registration failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _user = data['user'] as Map<String, dynamic>;
    await _persistTokens();

    // Identify in RevenueCat + check for override accounts
    if (_user != null && _user!['id'] != null) {
      await SubscriptionService.instance.logIn(_user!['id'].toString());
      SubscriptionService.instance.grantProOverride(
        _user!['email'] as String?,
      );
    }

    return _user!;
  }

  /// Login with email and password.
  Future<Map<String, dynamic>> emailLogin({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/email-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Invalid email or password');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _user = data['user'] as Map<String, dynamic>;
    await _persistTokens();

    // Identify in RevenueCat + check for override accounts
    if (_user != null && _user!['id'] != null) {
      await SubscriptionService.instance.logIn(_user!['id'].toString());
      SubscriptionService.instance.grantProOverride(
        _user!['email'] as String?,
      );
    }

    return _user!;
  }

  /// Refresh the access token.
  Future<void> refreshToken() async {
    if (_refreshToken == null) throw Exception('No refresh token');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': _refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('Refresh failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;

    await _persistTokens();
  }

  /// Get current user profile from backend.
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 401) {
      // Try refresh
      await refreshToken();
      return getProfile();
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to get profile');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _user = data;
    await _persistTokens();
    return data;
  }

  /// Delete user account.
  Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/auth/account'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete account');
    }

    await logout();
  }

  /// Clear all auth state.
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    // Clear secure storage (tokens)
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);

    // Clear shared preferences (user profile cache)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);

    // Log out from RevenueCat
    await SubscriptionService.instance.logOut();
  }

  /// Persist tokens to secure storage and user profile to SharedPreferences.
  Future<void> _persistTokens() async {
    if (_accessToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: _accessToken!);
    }
    if (_refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken!);
    }
    if (_user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(_user));
    }
  }
}
