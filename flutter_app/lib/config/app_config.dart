import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration persisted via SharedPreferences.
///
/// Environment defaults:
///   - Development: `ws://192.168.0.12:8000`
///   - Production: configured via Settings or build-time env vars
class AppConfig {
  AppConfig._({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  // ─── Keys ─────────────────────────────────
  static const String _keyHost = 'backend_host';
  static const String _keyPort = 'backend_port';
  static const String _keyProtocol = 'backend_protocol';

  // ─── Defaults ─────────────────────────────
  static const String defaultHost = '192.168.0.12';
  static const int defaultPort = 8000;
  static const String defaultProtocol = 'ws';

  // ─── Singleton init ───────────────────────

  static AppConfig? _instance;

  /// Initialize config from SharedPreferences. Call in main() before runApp.
  static Future<AppConfig> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _instance = AppConfig._(prefs: prefs);
    return _instance!;
  }

  /// Get the singleton instance. Throws if not initialized.
  static AppConfig get instance {
    if (_instance == null) {
      throw StateError('AppConfig.initialize() must be called before use');
    }
    return _instance!;
  }

  // ─── Getters ──────────────────────────────

  /// Backend host (IP or domain).
  String get host => _prefs.getString(_keyHost) ?? defaultHost;

  /// Backend port.
  int get port => _prefs.getInt(_keyPort) ?? defaultPort;

  /// WebSocket protocol (`ws` or `wss`).
  String get protocol => _prefs.getString(_keyProtocol) ?? defaultProtocol;

  /// Full WebSocket URL for the transcription endpoint.
  String get wsUrl => '$protocol://$host:$port/ws/transcription';

  /// Display-friendly backend URL (for Settings screen).
  String get displayUrl => '$host:$port';

  // ─── Setters ──────────────────────────────

  /// Update backend host.
  Future<void> setHost(String value) async {
    await _prefs.setString(_keyHost, value.trim());
  }

  /// Update backend port.
  Future<void> setPort(int value) async {
    await _prefs.setInt(_keyPort, value);
  }

  /// Update WebSocket protocol.
  Future<void> setProtocol(String value) async {
    await _prefs.setString(_keyProtocol, value.trim());
  }

  /// Update host and port from a "host:port" string.
  Future<void> setFromDisplayUrl(String displayUrl) async {
    final List<String> parts = displayUrl.trim().split(':');
    if (parts.isNotEmpty) {
      await setHost(parts[0]);
    }
    if (parts.length >= 2) {
      final int? port = int.tryParse(parts[1]);
      if (port != null) {
        await setPort(port);
      }
    }
  }

  /// Reset all config to defaults.
  Future<void> resetToDefaults() async {
    await _prefs.remove(_keyHost);
    await _prefs.remove(_keyPort);
    await _prefs.remove(_keyProtocol);
  }
}

/// Riverpod provider for AppConfig (initialized in main).
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.instance,
);
