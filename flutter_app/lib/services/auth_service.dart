import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meetmind/config/app_config.dart';

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
  String get _baseUrl {
    final config = AppConfig.instance;
    final scheme = config.protocol == 'wss' ? 'https' : 'http';
    return '$scheme://${config.host}:${config.port}';
  }

  /// Initialize from stored tokens (call on app startup).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);

    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = jsonDecode(userJson) as Map<String, dynamic>;
    }

    // Try refreshing if we have a refresh token but no valid access token
    if (_refreshToken != null) {
      try {
        await refreshToken();
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
        if (name != null) 'name': name,
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
        if (name != null) 'name': name,
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
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Invalid email or password');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _user = data['user'] as Map<String, dynamic>;
    await _persistTokens();
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
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
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
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  /// Persist tokens to secure storage.
  Future<void> _persistTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_accessTokenKey, _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString(_refreshTokenKey, _refreshToken!);
    }
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user));
    }
  }
}
