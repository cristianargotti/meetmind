import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meetmind/config/app_config.dart';

/// REST API service for meeting history and stats.
///
/// Communicates with the MeetMind backend's REST endpoints
/// for meeting CRUD, action items, and dashboard stats.
class MeetingApiService {
  MeetingApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Base URL for the REST API.
  String get _baseUrl {
    final config = AppConfig.instance;
    final protocol = config.protocol == 'wss' ? 'https' : 'http';
    return '$protocol://${config.host}:${config.port}';
  }

  /// Default request headers.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ─── Meetings ─────────────────────────────────────────────────

  /// List all meetings, most recent first.
  ///
  /// Returns a list of meeting summary maps.
  /// Throws [ApiException] on failure.
  Future<List<Map<String, dynamic>>> listMeetings({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _get('/api/meetings?limit=$limit&offset=$offset');
    final data = response['meetings'] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Get a single meeting with all its data.
  ///
  /// Returns complete meeting data including transcript, insights, summary.
  /// Throws [ApiException] if not found or on failure.
  Future<Map<String, dynamic>> getMeeting(String meetingId) async {
    return await _get('/api/meetings/$meetingId');
  }

  /// Delete a meeting and all related data.
  ///
  /// Returns true if deleted successfully.
  /// Throws [ApiException] if not found.
  Future<bool> deleteMeeting(String meetingId) async {
    final uri = Uri.parse('$_baseUrl/api/meetings/$meetingId');
    final response = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return true;
    }
    throw ApiException('Failed to delete meeting', response.statusCode);
  }

  // ─── Action Items ─────────────────────────────────────────────

  /// Get all pending action items across meetings.
  ///
  /// Returns a list of action item maps with meeting context.
  Future<List<Map<String, dynamic>>> getPendingActions({
    int limit = 50,
  }) async {
    final response = await _get('/api/action-items?limit=$limit');
    final data = response['action_items'] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Update an action item's status.
  ///
  /// Typically used to mark items as 'done'.
  Future<void> updateActionItem(int itemId, {String status = 'done'}) async {
    final uri = Uri.parse('$_baseUrl/api/action-items/$itemId?status=$status');
    final response = await _client
        .patch(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException('Failed to update action item', response.statusCode);
    }
  }

  // ─── Stats ────────────────────────────────────────────────────

  /// Get dashboard statistics.
  ///
  /// Returns aggregated stats: total meetings, hours, insights, etc.
  Future<Map<String, dynamic>> getStats() async {
    return await _get('/api/stats');
  }

  // ─── Internal ─────────────────────────────────────────────────

  /// Perform a GET request and parse JSON response.
  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException('GET $path failed', response.statusCode);
  }

  /// Dispose the HTTP client.
  void dispose() {
    _client.close();
  }
}

/// Exception thrown by the API service.
class ApiException implements Exception {
  /// Create an API exception.
  const ApiException(this.message, this.statusCode);

  /// Error message.
  final String message;

  /// HTTP status code.
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
