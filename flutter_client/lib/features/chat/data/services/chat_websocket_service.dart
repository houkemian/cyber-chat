import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/constants/api_endpoints.dart';

enum SocketStatus { connecting, connected, disconnected }

class ChatSocketEvent {
  ChatSocketEvent({
    required this.type,
    required this.content,
    this.sender,
    this.timestamp,
    this.onlineCount,
  });

  final String type;
  final String content;
  final String? sender;
  final String? timestamp;
  final int? onlineCount;

  factory ChatSocketEvent.fromJson(Map<String, dynamic> json) {
    return ChatSocketEvent(
      type: json['type'] as String? ?? 'system',
      content: json['content'] as String? ?? '',
      sender: json['sender'] as String?,
      timestamp: json['timestamp'] as String?,
      onlineCount: json['online_count'] as int?,
    );
  }
}

class ChatWebSocketService {
  ChatWebSocketService({
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 450),
  });

  final int maxRetries;
  final Duration retryDelay;

  final StreamController<ChatSocketEvent> _eventController = StreamController.broadcast();
  final StreamController<SocketStatus> _statusController = StreamController.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _retries = 0;
  bool _manualClose = false;
  String? _roomId;
  String? _token;

  Stream<ChatSocketEvent> get events => _eventController.stream;
  Stream<SocketStatus> get status => _statusController.stream;

  Future<void> connect({
    required String roomId,
    required String token,
  }) async {
    _roomId = roomId;
    _token = token;
    _manualClose = false;
    _statusController.add(SocketStatus.connecting);

    final wsUrl =
        '${ApiEndpoints.chatWsBase}/${Uri.encodeComponent(roomId)}?token=${Uri.encodeComponent(token)}';

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await _subscription?.cancel();
    _subscription = _channel!.stream.listen(
      _onData,
      onDone: _onClosed,
      onError: (_) => _onClosed(),
      cancelOnError: true,
    );
    _statusController.add(SocketStatus.connected);
  }

  void sendMessage(String content) {
    if (_channel == null || content.trim().isEmpty) return;
    _channel!.sink.add(content.trim());
  }

  Future<void> disconnect() async {
    _manualClose = true;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _statusController.add(SocketStatus.disconnected);
  }

  void _onData(dynamic data) {
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      _eventController.add(ChatSocketEvent.fromJson(decoded));
    } catch (_) {
      // Ignore malformed packets for parity with web behavior.
    }
  }

  Future<void> _onClosed() async {
    if (_manualClose) return;
    _statusController.add(SocketStatus.disconnected);

    if (_retries >= maxRetries || _roomId == null || _token == null) {
      return;
    }

    _retries += 1;
    await Future<void>.delayed(retryDelay);
    await connect(roomId: _roomId!, token: _token!);
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventController.close();
    await _statusController.close();
  }
}
