import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/constants/api_endpoints.dart';

/// 与 `RoomChat.tsx` 对齐
const int kWsRetryMax = 2;
const Duration kWsRetryDelay = Duration(milliseconds: 450);
const Duration kWsHandshakeTimeout = Duration(milliseconds: 2500);

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

typedef WsGiveUpCallback = void Function(int lastAttempt);

/// 实时链路：握手超时、有限次重连、手动断开。
class ChatWebSocketService {
  ChatWebSocketService();

  final StreamController<ChatSocketEvent> _eventController = StreamController.broadcast();
  final StreamController<SocketStatus> _statusController = StreamController.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;

  int _generation = 0;
  bool _manualClose = false;
  String? _roomId;
  String? _token;
  WsGiveUpCallback? onGiveUp;

  Stream<ChatSocketEvent> get events => _eventController.stream;
  Stream<SocketStatus> get status => _statusController.stream;

  Future<void> connect({
    required String roomId,
    required String token,
  }) async {
    _manualClose = false;
    _roomId = roomId;
    _token = token;
    _generation++;
    final gen = _generation;
    await _disconnectSocketOnly();
    await _openRealtimeLink(gen, attempt: 0);
  }

  Future<void> _openRealtimeLink(int gen, {required int attempt}) async {
    if (gen != _generation || _manualClose || _roomId == null || _token == null) return;

    _statusController.add(SocketStatus.connecting);
    final uri =
        '${ApiEndpoints.chatWsBase}/${Uri.encodeComponent(_roomId!)}?token=${Uri.encodeComponent(_token!)}';

    WebSocket? socket;
    try {
      socket = await WebSocket.connect(uri).timeout(kWsHandshakeTimeout);
    } catch (_) {
      if (gen != _generation || _manualClose) return;
      _statusController.add(SocketStatus.disconnected);
      _afterClose(gen, attempt: attempt);
      return;
    }

    if (gen != _generation || _manualClose) {
      await socket.close();
      return;
    }

    _channel = IOWebSocketChannel(socket);
    _subscription = _channel!.stream.listen(
      _onData,
      onDone: () => _onSocketDone(gen, attempt),
      onError: (_) => _onSocketDone(gen, attempt),
      cancelOnError: false,
    );
    _statusController.add(SocketStatus.connected);
  }

  void _onData(dynamic data) {
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      _eventController.add(ChatSocketEvent.fromJson(decoded));
    } catch (_) {}
  }

  void _onSocketDone(int gen, int attempt) {
    if (gen != _generation || _manualClose) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _channel = null;
    _statusController.add(SocketStatus.disconnected);
    _afterClose(gen, attempt: attempt);
  }

  void _afterClose(int gen, {required int attempt}) {
    if (gen != _generation || _manualClose || _roomId == null || _token == null) return;

    if (attempt >= kWsRetryMax) {
      onGiveUp?.call(attempt);
      return;
    }

    final next = attempt + 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(kWsRetryDelay, () {
      unawaited(_openRealtimeLink(gen, attempt: next));
    });
  }

  void sendMessage(String content) {
    final text = content.trim();
    if (text.isEmpty || _channel == null) return;
    _channel!.sink.add(text);
  }

  Future<void> disconnect() async {
    _manualClose = true;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _statusController.add(SocketStatus.disconnected);
  }

  Future<void> _disconnectSocketOnly() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventController.close();
    await _statusController.close();
  }
}
