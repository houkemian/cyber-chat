import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/chat_rate_limit.dart';
import '../../../../core/storage/session_store.dart';
import '../../data/chat_remote_data_source.dart';
import '../../data/services/chat_websocket_service.dart';
import '../../domain/cfs_commands.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/room_presets.dart';

const int kMaxRoomMessages = 200;

final RegExp _wsJoinRe = RegExp(r'终端\s+<([^>]+)>\s*已接入');
final RegExp _wsLeaveRe = RegExp(r'终端\s+<([^>]+)>\s*已断开');

class RoomChatController extends ChangeNotifier {
  RoomChatController({
    required this.roomId,
    required this.cyberName,
    required this.token,
    ChatRemoteDataSource? api,
    ChatWebSocketService? ws,
  })  : _api = api ?? ChatRemoteDataSource(),
        _ws = ws ?? ChatWebSocketService();

  final String roomId;
  final String cyberName;
  final String token;

  final ChatRemoteDataSource _api;
  final ChatWebSocketService _ws;

  final List<UiChatMessage> messages = <UiChatMessage>[];
  List<UiChatMessage> rawHistory = <UiChatMessage>[];
  String draft = '';
  int onlineCount = 1;
  /// switching | online | offline
  String channelState = 'switching';
  int syncRenderedCount = 0;
  bool isHistorySyncing = false;
  bool showMembers = false;
  List<String> memberList = <String>[];
  List<AnnouncementItemDto> announcements = <AnnouncementItemDto>[];
  bool dataWipeActive = false;

  StreamSubscription<ChatSocketEvent>? _wsSub;
  StreamSubscription<SocketStatus>? _wsStatusSub;
  Timer? _historyTimer;
  Timer? _dataWipeTimer;
  final List<int> _sendTimestamps = <int>[];

  bool _disposed = false;

  RoomThemeKind get themeKind => roomThemeForId(roomId);

  String get roomDisplayName {
    for (final s in kPresetSectors) {
      if (s.id == roomId) return s.name;
    }
    return roomId;
  }

  List<UiChatMessage> get systemMessages =>
      messages.where((m) => m.type == 'system').toList(growable: false);

  List<UiChatMessage> get userMessages =>
      messages.where((m) => m.type == 'chat').toList(growable: false);

  Future<void> init() async {
    await _loadAnnouncements();
    await _bootstrapRealtime();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final items = await _api.fetchAnnouncements();
      if (items.isNotEmpty) {
        announcements = items;
      } else {
        announcements = _fallbackAnnouncementDtos();
      }
    } catch (_) {
      announcements = _fallbackAnnouncementDtos();
    }
    notifyListeners();
  }

  List<AnnouncementItemDto> _fallbackAnnouncementDtos() {
    return <AnnouncementItemDto>[
      const AnnouncementItemDto(
        id: 'ann-1',
        content:
            '欢迎接入赛博树洞 2000.exe · 禁止实名，允许发疯。本地消息列表最多保留最近 200 条，与频道历史同步上限一致。',
      ),
      const AnnouncementItemDto(
        id: 'ann-2',
        content: '当前节点状态稳定 · 多扇区同步运行中 · 请文明发言，共同维护数字秩序。',
      ),
      const AnnouncementItemDto(
        id: 'ann-3',
        content: '系统公告：Phase-3 升级中 · AI 气氛组即将接入 · 敬请期待更多赛博体验。',
      ),
    ];
  }

  Future<void> _bootstrapRealtime() async {
    channelState = 'switching';
    notifyListeners();

    await _wsSub?.cancel();
    await _wsStatusSub?.cancel();
    await _ws.disconnect();
    _historyTimer?.cancel();

    messages.clear();
    rawHistory = <UiChatMessage>[];
    syncRenderedCount = 0;
    memberList = <String>[];
    onlineCount = 1;
    isHistorySyncing = false;

    if (token.isEmpty) {
      channelState = 'offline';
      messages.add(
        UiChatMessage(
          id: _newId('sys'),
          type: 'system',
          content: '[系统提示] 未检测到身份令牌，请重新登录后接入频道。',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          systemKind: SystemKind.generic,
        ),
      );
      notifyListeners();
      return;
    }

    isHistorySyncing = true;
    notifyListeners();

    List<HistoryMessageDto> history;
    try {
      history = await _api.fetchHistory(roomId, limit: kMaxRoomMessages);
    } catch (_) {
      if (_disposed) return;
      messages.add(
        UiChatMessage(
          id: _newId('sys'),
          type: 'system',
          content: '[系统提示] 历史同步失败，已切换至实时链路重试。',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          systemKind: SystemKind.generic,
        ),
      );
      history = <HistoryMessageDto>[];
    }

    if (_disposed) return;

    rawHistory = history.asMap().entries.map((e) => _fromHistoryDto(e.value, e.key)).toList();

    _seedMembersFromHistory(rawHistory);

    if (rawHistory.isEmpty) {
      isHistorySyncing = false;
      notifyListeners();
      await _wireWebSocket();
      return;
    }

    var cursor = 0;
    _historyTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_disposed) return;
      if (cursor >= rawHistory.length) {
        _historyTimer?.cancel();
        isHistorySyncing = false;
        notifyListeners();
        unawaited(_wireWebSocket());
        return;
      }
      final end = (cursor + 3).clamp(0, rawHistory.length);
      messages.addAll(rawHistory.sublist(cursor, end));
      cursor = end;
      syncRenderedCount = cursor;
      _trimMessages();
      notifyListeners();
    });
  }

  void _seedMembersFromHistory(List<UiChatMessage> hist) {
    final seed = <String>[];
    for (final msg in hist) {
      if (msg.type != 'system') continue;
      final join = _wsJoinRe.firstMatch(msg.content);
      final leave = _wsLeaveRe.firstMatch(msg.content);
      if (join != null) {
        final name = join.group(1)!;
        if (!seed.contains(name)) seed.add(name);
      } else if (leave != null) {
        final name = leave.group(1)!;
        seed.remove(name);
      }
    }
    if (seed.isNotEmpty) {
      memberList = seed;
    }
  }

  Future<void> _wireWebSocket() async {
    if (_disposed || token.isEmpty) return;

    _ws.onGiveUp = (_) {
      if (_disposed) return;
      messages.add(
        UiChatMessage(
          id: _newId('sys-ws'),
          type: 'system',
          content: '[系统提示] 链路断开，请稍后重试或重新接入。',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          systemKind: SystemKind.generic,
        ),
      );
      channelState = 'offline';
      notifyListeners();
    };

    await _wsSub?.cancel();
    await _wsStatusSub?.cancel();

    _wsSub = _ws.events.listen(_onSocketEvent);
    _wsStatusSub = _ws.status.listen((SocketStatus s) {
      if (_disposed) return;
      if (s == SocketStatus.connected) {
        channelState = 'online';
        notifyListeners();
      } else if (s == SocketStatus.disconnected) {
        channelState = 'offline';
        notifyListeners();
      } else if (s == SocketStatus.connecting) {
        channelState = 'switching';
        notifyListeners();
      }
    });

    await _ws.connect(roomId: roomId, token: token);
  }

  void _onSocketEvent(ChatSocketEvent raw) {
    if (_disposed) return;
    final ts = raw.timestamp ?? DateTime.now().toUtc().toIso8601String();
    if (raw.type == 'system') {
      var kind = SystemKind.generic;
      if (raw.content.contains('已接入')) {
        kind = SystemKind.join;
      } else if (raw.content.contains('已断开')) {
        kind = SystemKind.leave;
      }
      final msg = UiChatMessage(
        id: _newId('sys'),
        type: 'system',
        content: raw.content,
        timestamp: ts,
        systemKind: kind,
      );
      messages.add(msg);
      if (raw.onlineCount != null) {
        onlineCount = raw.onlineCount!;
        _applyPresenceFromSystem(raw.content, raw.onlineCount!);
      }
    } else {
      messages.add(
        UiChatMessage(
          id: _newId('chat'),
          type: 'chat',
          sender: raw.sender,
          content: raw.content,
          timestamp: ts,
        ),
      );
    }
    _trimMessages();
    notifyListeners();
  }

  void _applyPresenceFromSystem(String content, int online) {
    final join = _wsJoinRe.firstMatch(content);
    final leave = _wsLeaveRe.firstMatch(content);
    if (join != null) {
      final name = join.group(1)!;
      if (!memberList.contains(name)) {
        memberList = <String>[...memberList, name];
      }
    } else if (leave != null) {
      final name = leave.group(1)!;
      memberList = memberList.where((n) => n != name).toList();
    }
    if (memberList.length != online) {
      unawaited(refreshMembersFromApi());
    }
  }

  Future<void> refreshMembersFromApi() async {
    try {
      final dto = await _api.fetchMembers(roomId);
      memberList = dto.members;
      onlineCount = dto.onlineCount;
      notifyListeners();
    } catch (_) {}
  }

  void setDraft(String value) {
    draft = value;
    notifyListeners();
  }

  Future<void> sendDraft() async {
    final content = draft.trim();
    if (content.isEmpty) return;

    if (isCfsSlashCommand(content)) {
      final cmd = content.toLowerCase();
      if (cmd == '/clear') {
        messages.clear();
        draft = '';
        dataWipeActive = true;
        _dataWipeTimer?.cancel();
        _dataWipeTimer = Timer(const Duration(seconds: 2), () {
          if (_disposed) return;
          dataWipeActive = false;
          messages.add(
            UiChatMessage(
              id: _newId('cfs-erase'),
              type: 'system',
              content: '[CFS] SECURE_ERASE 完成 · 本地缓冲区已归零',
              timestamp: DateTime.now().toUtc().toIso8601String(),
              systemKind: SystemKind.generic,
            ),
          );
          notifyListeners();
        });
        notifyListeners();
        return;
      }
      if (cmd == '/whoami') {
        final text = await buildCfsWhoami(
          cyberName: cyberName,
          roomId: roomId,
          roomName: roomDisplayName,
        );
        messages.add(
          UiChatMessage(
            id: _newId('cfs'),
            type: 'system',
            content: text,
            timestamp: DateTime.now().toUtc().toIso8601String(),
            systemKind: SystemKind.cfs,
          ),
        );
        draft = '';
        _trimMessages();
        notifyListeners();
        return;
      }
      if (cmd == '/ls') {
        final self = await SessionStore.readCyberName();
        final merged = <String>{if (self != null) self, ...memberList}.toList();
        final ann = announcements
            .map((a) => (id: a.id, content: a.content))
            .toList(growable: false);
        final text = buildCfsLs(roomName: roomDisplayName, members: merged, announcements: ann);
        messages.add(
          UiChatMessage(
            id: _newId('cfs'),
            type: 'system',
            content: text,
            timestamp: DateTime.now().toUtc().toIso8601String(),
            systemKind: SystemKind.cfs,
          ),
        );
        draft = '';
        _trimMessages();
        notifyListeners();
        return;
      }
    }

    if (channelState != 'online') {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _sendTimestamps.removeWhere((t) => now - t >= ChatRateLimit.windowMs);
    if (_sendTimestamps.length >= ChatRateLimit.maxSendsPerSecond) {
      messages.add(
        UiChatMessage(
          id: _newId('sys-rate'),
          type: 'system',
          content: '[系统提示] 发送过快：每位用户每秒最多发送 2 条消息。',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          systemKind: SystemKind.generic,
        ),
      );
      notifyListeners();
      return;
    }
    _sendTimestamps.add(now);
    _ws.sendMessage(content);
    draft = '';
    notifyListeners();
  }

  void setShowRadar(bool value) {
    showMembers = value;
    if (value) {
      unawaited(refreshMembersFromApi());
    }
    notifyListeners();
  }

  void _trimMessages() {
    if (messages.length <= kMaxRoomMessages) return;
    messages.removeRange(0, messages.length - kMaxRoomMessages);
  }

  UiChatMessage _fromHistoryDto(HistoryMessageDto dto, int index) {
    final ts = dto.timestamp;
    if (dto.type == 'system') {
      var kind = SystemKind.generic;
      if (dto.content.contains('已接入')) {
        kind = SystemKind.join;
      } else if (dto.content.contains('已断开')) {
        kind = SystemKind.leave;
      }
      return UiChatMessage(
        id: 'hist-$roomId-$index-$ts',
        type: 'system',
        content: dto.content,
        timestamp: ts,
        systemKind: kind,
        isHistory: true,
      );
    }
    return UiChatMessage(
      id: 'hist-$roomId-$index-$ts',
      type: 'chat',
      sender: dto.sender,
      content: dto.content,
      timestamp: ts,
      isHistory: true,
    );
  }

  String _newId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _historyTimer?.cancel();
    _dataWipeTimer?.cancel();
    unawaited(_wsSub?.cancel());
    unawaited(_wsStatusSub?.cancel());
    unawaited(_ws.dispose());
    _api.dispose();
    super.dispose();
  }
}
