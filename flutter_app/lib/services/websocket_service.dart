import 'dart:async';
import 'dart:convert';

import 'package:meetmind/models/meeting_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket service for connecting to MeetMind backend.
class WebSocketService {
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _connectionId;

  final StreamController<Map<String, Object?>> _messageController =
      StreamController<Map<String, Object?>>.broadcast();

  /// Stream of incoming messages from the backend.
  Stream<Map<String, Object?>> get messages => _messageController.stream;

  /// Current connection status.
  ConnectionStatus get status => _status;

  /// Connection ID assigned by the backend.
  String? get connectionId => _connectionId;

  /// Connect to the backend WebSocket.
  Future<void> connect({String host = 'localhost', int port = 8000}) async {
    if (_status == ConnectionStatus.connected) return;

    _status = ConnectionStatus.connecting;

    try {
      final Uri uri = Uri.parse('ws://$host:$port/ws/transcription');
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;
      _status = ConnectionStatus.connected;

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
        },
        onDone: () {
          _status = ConnectionStatus.disconnected;
          _connectionId = null;
        },
      );
    } catch (e) {
      _status = ConnectionStatus.error;
      rethrow;
    }
  }

  /// Send a transcript chunk to the backend.
  void sendTranscript(String text, {String speaker = 'user'}) {
    if (_status != ConnectionStatus.connected || _channel == null) return;

    _channel!.sink.add(
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

  /// Disconnect from the backend.
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _status = ConnectionStatus.disconnected;
    _connectionId = null;
  }

  /// Dispose all resources.
  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
