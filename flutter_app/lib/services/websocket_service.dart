import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:meetmind/models/meeting_models.dart';
import 'package:meetmind/services/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket service with auto-reconnect for MeetMind backend.
class WebSocketService {
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _connectionId;
  String? _lastUrl;

  // Reconnection state
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);

  // Buffered segments during disconnection
  final List<String> _pendingMessages = [];

  final StreamController<Map<String, Object?>> _messageController =
      StreamController<Map<String, Object?>>.broadcast();

  /// Stream of incoming messages from the backend.
  Stream<Map<String, Object?>> get messages => _messageController.stream;

  /// Current connection status.
  ConnectionStatus get status => _status;

  /// Connection ID assigned by the backend.
  String? get connectionId => _connectionId;

  /// Connect to the backend WebSocket.
  ///
  /// Appends the JWT access token as `?token=` query parameter for
  /// backend authentication.
  Future<void> connect({required String wsUrl}) async {
    if (_status == ConnectionStatus.connected) return;

    _lastUrl = wsUrl;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    await _doConnect(wsUrl);
  }

  /// Internal connect with optional reconnection context.
  Future<void> _doConnect(String wsUrl) async {
    _status = ConnectionStatus.connecting;

    try {
      // Append JWT token for authentication
      final token = AuthService.instance.accessToken;
      final uri = Uri.parse(wsUrl);
      final authedUri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          // ignore: use_null_aware_elements
          if (token != null) 'token': token,
        },
      );
      _channel = WebSocketChannel.connect(authedUri);

      await _channel!.ready;
      _status = ConnectionStatus.connected;
      _reconnectAttempts = 0;

      // Flush any buffered messages
      _flushPendingMessages();

      _channel!.stream.listen(
        (Object? data) {
          final Map<String, Object?> message =
              jsonDecode(data! as String) as Map<String, Object?>;

          // Capture connection ID from welcome message
          if (message['type'] == 'connected') {
            _connectionId = message['connection_id'] as String?;
          }

          _messageController.add(message);
        },
        onError: (Object error) {
          _status = ConnectionStatus.error;
          _messageController.addError(error);
          _scheduleReconnect();
        },
        onDone: () {
          _status = ConnectionStatus.disconnected;
          _connectionId = null;
          if (!_intentionalDisconnect) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      _status = ConnectionStatus.error;
      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      } else {
        rethrow;
      }
    }
  }

  /// Schedule a reconnection attempt with exponential backoff.
  void _scheduleReconnect() {
    if (_intentionalDisconnect || _lastUrl == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        debugPrint('🔴 WebSocket: max reconnect attempts reached');
      }
      _status = ConnectionStatus.error;
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: min(
        _baseDelay.inMilliseconds * pow(2, _reconnectAttempts - 1).toInt(),
        _maxDelay.inMilliseconds,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        '🔄 WebSocket: reconnecting in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts/$_maxReconnectAttempts)',
      );
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!_intentionalDisconnect && _lastUrl != null) {
        // Close stale channel before reconnecting
        try {
          await _channel?.sink.close();
        } catch (_) {}
        _channel = null;
        await _doConnect(_lastUrl!);
      }
    });
  }

  /// Flush messages that were buffered during disconnection.
  void _flushPendingMessages() {
    if (_channel == null || _pendingMessages.isEmpty) return;
    for (final msg in _pendingMessages) {
      _channel!.sink.add(msg);
    }
    _pendingMessages.clear();
  }

  /// Send a message, buffering if disconnected.
  void _sendOrBuffer(String encoded) {
    if (_status == ConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(encoded);
    } else {
      _pendingMessages.add(encoded);
    }
  }

  /// Send a transcript chunk to the backend.
  void sendTranscript(String text, {String speaker = 'user'}) {
    _sendOrBuffer(
      jsonEncode(<String, String>{
        'type': 'transcript',
        'text': text,
        'speaker': speaker,
      }),
    );
  }

  /// Send a ping to keep the connection alive.
  void sendPing() {
    if (_status != ConnectionStatus.connected || _channel == null) return;
    _channel!.sink.add(jsonEncode(<String, String>{'type': 'ping'}));
  }

  /// Send a copilot question to the backend.
  void sendCopilotQuery(String question) {
    _sendOrBuffer(
      jsonEncode(<String, String>{
        'type': 'copilot_query',
        'question': question,
      }),
    );
  }

  /// Request meeting summary generation from the backend.
  void sendSummaryRequest() {
    _sendOrBuffer(
      jsonEncode(<String, String>{'type': 'generate_summary'}),
    );
  }

  /// Send raw PCM audio bytes to the backend for server-side STT.
  void sendAudio(List<int> pcmBytes) {
    if (_status != ConnectionStatus.connected || _channel == null) return;
    _channel!.sink.add(pcmBytes);
  }

  /// Disconnect from the backend (intentional).
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pendingMessages.clear();
    await _channel?.sink.close();
    _channel = null;
    _status = ConnectionStatus.disconnected;
    _connectionId = null;
  }

  /// Dispose all resources.
  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _messageController.close();
  }
}
