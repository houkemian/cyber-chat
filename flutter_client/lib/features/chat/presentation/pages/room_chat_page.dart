import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/constants/avatar_pool.dart';
import '../../../../app/widgets/pixel_emoji_avatar.dart';
import '../../../../app/widgets/pix_button.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/pixel_style.dart';
import '../../../../core/theme/theme.dart';
import '../../data/chat_remote_data_source.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/room_presets.dart';
import '../controllers/room_chat_controller.dart';
import '../utils/chat_clock.dart';

class RoomChatPage extends StatefulWidget {
  const RoomChatPage({
    super.key,
    this.avatarIdx = 0,
    this.shellCyberName,
  });

  /// 与 [CyberHeaderBar] 同步；用于聊天行「本人」头像与顶栏一致。
  final int avatarIdx;

  /// 当前登录赛博名；与 [SessionStore] 一致时用于判定本人消息。
  final String? shellCyberName;

  @override
  State<RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends State<RoomChatPage> {
  final ScrollController _sysScroll = ScrollController();
  final ScrollController _usrScroll = ScrollController();
  late TextEditingController _draftInput;
  late RoomChatController _controller;
  String _roomId = 'sector-001';
  bool _chaosFx = false;
  String _token = '';
  String _cyberName = 'ANON';
  bool _loadingShell = true;

  @override
  void initState() {
    super.initState();
    _draftInput = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _token = (await SessionStore.readToken()) ?? '';
    _cyberName = widget.shellCyberName ?? (await SessionStore.readCyberName()) ?? 'ANON';
    _controller = RoomChatController(
      roomId: _roomId,
      cyberName: _cyberName,
      token: _token,
    );
    _controller.addListener(_onRoomTick);
    await _controller.init();
    if (!mounted) return;
    setState(() {
      _loadingShell = false;
    });
  }

  @override
  void didUpdateWidget(RoomChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shellCyberName != oldWidget.shellCyberName &&
        widget.shellCyberName != null &&
        widget.shellCyberName!.trim().isNotEmpty) {
      _cyberName = widget.shellCyberName!;
    }
  }

  void _onRoomTick() {
    if (_draftInput.text != _controller.draft) {
      _draftInput.value = TextEditingValue(
        text: _controller.draft,
        selection: TextSelection.collapsed(offset: _controller.draft.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sysScroll.hasClients) {
        _sysScroll.jumpTo(_sysScroll.position.maxScrollExtent);
      }
      if (_usrScroll.hasClients) {
        _usrScroll.jumpTo(_usrScroll.position.maxScrollExtent);
      }
    });
    setState(() {});
  }

  Future<void> _onSectorTap(String id) async {
    if (id == _roomId) return;
    setState(() => _chaosFx = true);
    _controller.removeListener(_onRoomTick);
    _controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _roomId = id;
      _chaosFx = false;
      _controller = RoomChatController(
        roomId: _roomId,
        cyberName: _cyberName,
        token: _token,
      );
    });
    _controller.addListener(_onRoomTick);
    await _controller.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onRoomTick);
    _controller.dispose();
    _sysScroll.dispose();
    _usrScroll.dispose();
    _draftInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingShell) {
      return const Scaffold(
        backgroundColor: CyberPalette.pureBlack,
        body: Center(
          child: CircularProgressIndicator(color: CyberPalette.terminalGreen),
        ),
      );
    }

    final tokens = RoomThemeTokens.forKind(_controller.themeKind);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SectorTabBar(
                    roomId: _roomId,
                    tokens: tokens,
                    onSelect: _onSectorTap,
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.35, -0.55),
                        radius: 1.45,
                        colors: <Color>[
                          tokens.neonPrimary.withValues(alpha: 0.12),
                          Color.lerp(tokens.neonPrimary, const Color(0xFFBC00FF), 0.35)!.withValues(alpha: 0.04),
                          const Color(0xFF050510),
                        ],
                        stops: const <double>[0.0, 0.45, 1.0],
                      ),
                      ),
                      child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 72,
                          child: _AnnouncementStrip(
                            items: _controller.announcements,
                            tokens: tokens,
                          ),
                        ),
                        SizedBox(
                          height: 110,
                          child: _SystemFeed(
                            scroll: _sysScroll,
                            messages: _controller.systemMessages,
                            tokens: tokens,
                          ),
                        ),
                        Expanded(
                          child: _UserStream(
                            scroll: _usrScroll,
                            messages: _controller.userMessages,
                            isSyncing: _controller.isHistorySyncing,
                            tokens: tokens,
                            channelOnline: _controller.channelState == 'online',
                            onlineCount: _controller.onlineCount,
                            selfAvatarIdx: widget.avatarIdx,
                            selfCyberName: widget.shellCyberName ?? _cyberName,
                          ),
                        ),
                        if (_controller.isHistorySyncing)
                          _SyncBar(
                            rendered: _controller.syncRenderedCount,
                            buffered: _controller.rawHistory.length,
                            tokens: tokens,
                          ),
                        _CmdPanel(
                          tokens: tokens,
                          draft: _draftInput,
                          channelOnline: _controller.channelState == 'online',
                          onChanged: _controller.setDraft,
                          onSend: () => unawaited(_controller.sendDraft()),
                          onRadar: () => _controller.setShowRadar(true),
                        ),
                      ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_controller.channelState == 'switching')
            _SwitchingOverlay(roomId: _roomId, roomName: _controller.roomDisplayName, tokens: tokens),
          if (_chaosFx) const _ChaosOverlay(),
          if (_controller.dataWipeActive) const _DataWipeOverlay(),
          if (_controller.showMembers)
            _RadarOverlay(
              roomName: _controller.roomDisplayName,
              members: _controller.memberList,
              onClose: () => _controller.setShowRadar(false),
            ),
        ],
      ),
    );
  }
}

class _SectorTabBar extends StatelessWidget {
  const _SectorTabBar({
    required this.roomId,
    required this.tokens,
    required this.onSelect,
  });

  final String roomId;
  final RoomThemeTokens tokens;
  final void Function(String id) onSelect;

  static String _shortSectorId(String id) {
    final i = id.lastIndexOf('-');
    return i < 0 ? id : id.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    const Color lineDim = Color(0xFF1A4030);
    const Color bgCell = Color(0xFF020403);
    const Color borderIdle = Color(0xFF2E2E32);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF010203),
        border: Border(
          bottom: BorderSide(color: lineDim, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              '┌─ SECTOR_MAP.EXE ─ CHANNEL SELECT ─────────────────────────',
              style: PixelStyle.vt323(
                fontSize: 11,
                letterSpacing: 0.5,
                color: CyberPalette.terminalGreen.withValues(alpha: 0.45),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final MapEntry<int, SectorPreset> e in kPresetSectors.asMap().entries)
                  ...<Widget>[
                    if (e.key > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '¦',
                          style: PixelStyle.vt323(fontSize: 12, color: lineDim.withValues(alpha: 0.9)),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => onSelect(e.value.id),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 168),
                        child: () {
                          final SectorPreset s = e.value;
                          final bool active = s.id == roomId;
                          final String sid = _shortSectorId(s.id);
                          return Container(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF050A08) : bgCell,
                              border: Border.all(
                                color: active ? tokens.neonPrimary : borderIdle,
                                width: active ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '[ CH-$sid ]',
                                  style: PixelStyle.vt323(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: active
                                        ? tokens.terminalAmber.withValues(alpha: 0.95)
                                        : CyberPalette.terminalGreen.withValues(alpha: 0.42),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PixelStyle.vt323(
                                    fontSize: 12,
                                    height: 1.2,
                                    color: active
                                        ? tokens.neonPrimary.withValues(alpha: 0.95)
                                        : const Color(0xFF7A8B90),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }(),
                      ),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementStrip extends StatefulWidget {
  const _AnnouncementStrip({required this.items, required this.tokens});

  final List<AnnouncementItemDto> items;
  final RoomThemeTokens tokens;

  @override
  State<_AnnouncementStrip> createState() => _AnnouncementStripState();
}

class _AnnouncementStripState extends State<_AnnouncementStrip> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final len = _effectiveList().length;
      setState(() {
        _idx = len == 0 ? 0 : (_idx + 1) % len;
      });
    });
  }

  List<AnnouncementItemDto> _fallback() {
    return const <AnnouncementItemDto>[
      AnnouncementItemDto(id: '1', content: 'BROADCAST SIGNAL · 节点在线'),
    ];
  }

  List<AnnouncementItemDto> _effectiveList() {
    return widget.items.isEmpty ? _fallback() : widget.items;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _effectiveList();
    final safeIdx = list.isEmpty ? 0 : _idx % list.length;
    final text = list.isEmpty ? '' : list[safeIdx].content;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x59FFC800)),
        color: const Color(0xBF140E00),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0x2EFFB400),
                  widget.tokens.neonSecondary.withValues(alpha: 0.06),
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFFFFB800), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'BROADCAST://SIGNAL',
                  style: TextStyle(
                    fontFamily: CyberFonts.pixel,
                    fontSize: 10,
                    letterSpacing: 2,
                    color: widget.tokens.neonPrimary.withValues(alpha: 0.88),
                  ),
                ),
                const Spacer(),
                Text('◈ ALERT', style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 10, color: Colors.orange.shade700)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('📡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: CyberFonts.pixel,
                        fontSize: 11,
                        height: 1.45,
                        color: widget.tokens.neonPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemFeed extends StatelessWidget {
  const _SystemFeed({
    required this.scroll,
    required this.messages,
    required this.tokens,
  });

  final ScrollController scroll;
  final List<UiChatMessage> messages;
  final RoomThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Color.lerp(tokens.terminalAmber, Colors.black, 0.65)!),
        color: const Color(0xA615100B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(
            title: 'SYS://FEED',
            accent: tokens.terminalAmber,
            badge: '◈ MONITOR',
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      '[系统提示] 暂无系统信号',
                      style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 12, color: Color(0xB8FDE68A)),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _SystemLine(msg: messages[i], tokens: tokens),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserStream extends StatelessWidget {
  const _UserStream({
    required this.scroll,
    required this.messages,
    required this.isSyncing,
    required this.tokens,
    required this.channelOnline,
    required this.onlineCount,
    required this.selfAvatarIdx,
    required this.selfCyberName,
  });

  final ScrollController scroll;
  final List<UiChatMessage> messages;
  final bool isSyncing;
  final RoomThemeTokens tokens;
  final bool channelOnline;
  final int onlineCount;
  final int selfAvatarIdx;
  final String selfCyberName;

  @override
  Widget build(BuildContext context) {
    final lastHistoryIdx = messages.lastIndexWhere((m) => m.isHistory);
    final showDivider = !isSyncing && lastHistoryIdx >= 0;

    final bodyChildren = <Widget>[];
    for (var i = 0; i < messages.length; i += 1) {
      bodyChildren.add(
        _ChatLine(
          msg: messages[i],
          index: i,
          tokens: tokens,
          selfAvatarIdx: selfAvatarIdx,
          selfCyberName: selfCyberName,
        ),
      );
      if (showDivider && i == lastHistoryIdx) {
        bodyChildren.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(
                'DATA ECHO · 数据残响 ▾',
                style: TextStyle(
                  fontFamily: CyberFonts.pixel,
                  fontSize: 10,
                  letterSpacing: 3,
                  color: Color(0xBFC026D3),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.neonPrimary.withValues(alpha: 0.35)),
        color: const Color(0x9E0B1223),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(
            title: 'USR://STREAM',
            accent: tokens.neonPrimary,
            badge: '◈ LIVE',
            trailing: 'ONLINE $onlineCount',
            dotOnline: channelOnline,
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      '[系统提示] 正在接入扇区主干网络...',
                      style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(8),
                    children: bodyChildren,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.accent,
    required this.badge,
    this.trailing,
    this.dotOnline,
  });

  final String title;
  final Color accent;
  final String badge;
  final String? trailing;
  final bool? dotOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.35))),
        gradient: LinearGradient(
          colors: <Color>[accent.withValues(alpha: 0.2), Colors.transparent],
        ),
      ),
      child: Row(
        children: <Widget>[
          if (dotOnline != null)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: dotOnline! ? const Color(0xFF22D3EE) : const Color(0xFF164E63),
                shape: BoxShape.circle,
              ),
            ),
          Text(
            title,
            style: TextStyle(
              fontFamily: CyberFonts.pixel,
              fontSize: 11,
              letterSpacing: 4,
              color: accent.withValues(alpha: 0.95),
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontFamily: CyberFonts.pixel, fontSize: 10, color: Color(0xBF67E8F9))),
          const SizedBox(width: 8),
          Text(badge, style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 10, color: accent.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.msg, required this.tokens});

  final UiChatMessage msg;
  final RoomThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (msg.systemKind == SystemKind.cfs) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('◈', style: TextStyle(fontSize: 9, color: Color(0xE622D3EE))),
                const SizedBox(width: 6),
                Text(
                  '[${formatChatClock(msg.timestamp)}]',
                  style: const TextStyle(fontFamily: CyberFonts.pixel, fontSize: 10, color: Color(0xBF94A3B8)),
                ),
                const SizedBox(width: 6),
                const Text('CFS', style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 9, color: Color(0xE622D3EE))),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              msg.content,
              style: const TextStyle(
                fontFamily: CyberFonts.pixel,
                fontSize: 9,
                height: 1.38,
                color: Color(0xE5FDE68A),
              ),
            ),
          ],
        ),
      );
    }

    final join = msg.systemKind == SystemKind.join;
    final leave = msg.systemKind == SystemKind.leave;
    final border = join
        ? const Color(0x9922D3EE)
        : leave
            ? const Color(0x8DFB7185)
            : const Color(0x59FDE68A);
    final icon = join ? '▶' : leave ? '◀' : '◈';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: border, width: 2)),
        color: join
            ? const Color(0x0A22C55E)
            : leave
                ? const Color(0x08EF4444)
                : Colors.transparent,
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 11, color: tokens.terminalAmber.withValues(alpha: 0.88)),
          children: <InlineSpan>[
            TextSpan(text: '$icon ', style: TextStyle(color: join ? const Color(0xDE86EFAC) : const Color(0xDFF87171))),
            TextSpan(
              text: '[${formatChatClock(msg.timestamp)}] ',
              style: const TextStyle(color: Color(0xBF94A3B8), fontSize: 10),
            ),
            TextSpan(text: msg.content),
          ],
        ),
      ),
    );
  }
}

/// 聊天行头像：他人用昵称种子 pixel-art；本人与顶栏 [kAvatarPool] / [dicebearUrlForPoolEntry] 一致。
class _ChatLineAvatar extends StatelessWidget {
  const _ChatLineAvatar({
    required this.displayName,
    required this.size,
    required this.selfCyberName,
    required this.selfAvatarIdx,
  });

  final String displayName;
  final double size;
  final String selfCyberName;
  final int selfAvatarIdx;

  bool get _isSelf {
    final String a = displayName.trim();
    final String b = selfCyberName.trim();
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  @override
  Widget build(BuildContext context) {
    final double s = size.clamp(12, 48);
    if (_isSelf) {
      final int idx = selfAvatarIdx.clamp(0, kAvatarPool.length - 1);
      final AvatarPoolEntry entry = kAvatarPool[idx];
      final String? url = dicebearUrlForPoolEntry(entry, selfCyberName, size: 96);
      final String? emoji = entry.pixelEmoji?.trim();
      if (emoji != null && emoji.isNotEmpty) {
        return SizedBox(
          width: s,
          height: s,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334455), width: 1)),
            child: PixelatedEmojiAvatar(emoji: emoji, size: s, showFrame: false),
          ),
        );
      }
      final String u = url ?? dicebearPixelArtPngUrl(selfCyberName, size: 96);
      return SizedBox(
        width: s,
        height: s,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334455), width: 1)),
          child: Image.network(
            u,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
            cacheWidth: 96,
            cacheHeight: 96,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1520)),
          ),
        ),
      );
    }

    final String name = displayName.trim().isEmpty ? 'ANON' : displayName.trim();
    final String url = dicebearPixelArtPngUrl(name, size: 96);
    return SizedBox(
      width: s,
      height: s,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334455), width: 1)),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          gaplessPlayback: true,
          cacheWidth: 96,
          cacheHeight: 96,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1520)),
        ),
      ),
    );
  }
}

class _ChatLine extends StatelessWidget {
  const _ChatLine({
    required this.msg,
    required this.index,
    required this.tokens,
    required this.selfAvatarIdx,
    required this.selfCyberName,
  });

  final UiChatMessage msg;
  final int index;
  final RoomThemeTokens tokens;
  final int selfAvatarIdx;
  final String selfCyberName;

  static const double _nameFontSize = 12;
  static const double _avatarSize = 20;

  @override
  Widget build(BuildContext context) {
    final odd = index.isOdd;
    final String displayName = msg.sender ?? 'ANON';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.fromLTRB(odd ? 10 : 8, 6, 8, 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: odd ? tokens.neonSecondary.withValues(alpha: 0.2) : tokens.neonPrimary.withValues(alpha: 0.2),
            style: BorderStyle.solid,
          ),
          left: odd ? BorderSide(color: tokens.neonSecondary.withValues(alpha: 0.42), width: 2) : BorderSide.none,
        ),
        color: odd ? tokens.neonSecondary.withValues(alpha: 0.06) : Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _ChatLineAvatar(
            displayName: displayName,
            size: _avatarSize,
            selfCyberName: selfCyberName,
            selfAvatarIdx: selfAvatarIdx,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: CyberFonts.pixel, height: 1.65),
                children: <InlineSpan>[
                  TextSpan(
                    text: '$displayName ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: _nameFontSize,
                      color: odd ? tokens.neonSecondary : tokens.neonPrimary,
                    ),
                  ),
                  TextSpan(
                    text: '[${formatChatClock(msg.timestamp)}] ',
                    style: const TextStyle(fontSize: 11, color: Color(0xD964748B)),
                  ),
                  TextSpan(
                    text: msg.content,
                    style: const TextStyle(fontSize: 13, color: Color(0xF3E2E8F0)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBar extends StatelessWidget {
  const _SyncBar({
    required this.rendered,
    required this.buffered,
    required this.tokens,
  });

  final int rendered;
  final int buffered;
  final RoomThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final pct = (rendered / 200).clamp(0.02, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2D2D2D))),
        color: Color(0xFF09070F),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '[ 同步中: ${rendered.clamp(0, 200)}/200 ]',
                style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 12, color: tokens.neonPrimary.withValues(alpha: 0.82)),
              ),
              Text('$buffered buffered', style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 12, color: tokens.neonPrimary.withValues(alpha: 0.82))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.8),
              color: tokens.neonPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CmdPanel extends StatefulWidget {
  const _CmdPanel({
    required this.tokens,
    required this.draft,
    required this.channelOnline,
    required this.onChanged,
    required this.onSend,
    required this.onRadar,
  });

  final RoomThemeTokens tokens;
  final TextEditingController draft;
  final bool channelOnline;
  final void Function(String) onChanged;
  final VoidCallback onSend;
  final VoidCallback onRadar;

  @override
  State<_CmdPanel> createState() => _CmdPanelState();
}

class _CmdPanelState extends State<_CmdPanel> {
  final FocusNode _fieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fieldFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fieldFocus.dispose();
    super.dispose();
  }

  bool _cfsAllowed(String text) {
    final c = text.trim().toLowerCase();
    return c == '/whoami' || c == '/ls' || c == '/clear';
  }

  @override
  Widget build(BuildContext context) {
    final RoomThemeTokens t = widget.tokens;
    final offlineExec = !widget.channelOnline && !_cfsAllowed(widget.draft.text);
    final g = CyberPalette.terminalGreen;
    final bool focus = _fieldFocus.hasFocus;
    final Color accent = t.neonPrimary;
    final Color edgeIdle = accent.withValues(alpha: focus ? 0.75 : 0.42);

    final Border sunken = Border(
      top: BorderSide(color: const Color(0xFF020810), width: 2),
      left: BorderSide(color: const Color(0xFF020810), width: 2),
      bottom: BorderSide(color: edgeIdle, width: focus ? 2 : 1),
      right: BorderSide(color: edgeIdle, width: focus ? 2 : 1),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(accent, const Color(0xFFBC00FF), 0.25)!.withValues(alpha: 0.14),
            const Color(0xFF050510),
            const Color(0xFF030308),
          ],
          stops: const <double>[0.0, 0.35, 1.0],
        ),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.55), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              '┌─ TX_BUFFER.EXE ─ UPLINK ───────────────────',
              style: PixelStyle.vt323(
                fontSize: 10,
                letterSpacing: 0.25,
                color: CyberPalette.neonCyan.withValues(alpha: 0.38),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onRadar,
                  child: Tooltip(
                    message: '终端雷达 · 扫描同频节点',
                    child: Container(
                      width: 44,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF060814),
                        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1),
                      ),
                      child: CustomPaint(
                        size: const Size(30, 28),
                        painter: _RadarGlyphPainter(
                          accent: accent,
                          dim: t.neonSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF010206),
                    border: sunken,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '>',
                        style: PixelStyle.vt323(
                          fontSize: 15,
                          color: accent.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '//',
                        style: PixelStyle.vt323(fontSize: 15, color: g.withValues(alpha: 0.45)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.draft,
                          focusNode: _fieldFocus,
                          onChanged: widget.onChanged,
                          style: PixelStyle.vt323(
                            fontSize: 15,
                            height: 1.35,
                            color: widget.channelOnline ? g : g.withValues(alpha: 0.45),
                          ),
                          cursorColor: g,
                          cursorWidth: 2,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: widget.channelOnline
                                ? '/whoami  /ls  /clear  · 广播...'
                                : 'OFFLINE · /whoami /ls /clear',
                            hintStyle: PixelStyle.vt323(
                              fontSize: 12,
                              height: 1.3,
                              color: widget.channelOnline
                                  ? accent.withValues(alpha: 0.28)
                                  : const Color(0x77FF6B6B),
                            ),
                          ),
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => widget.onSend(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PixButton(
                onTap: offlineExec ? null : widget.onSend,
                enabled: !offlineExec,
                width: 76,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                face: offlineExec
                    ? Color.lerp(const Color(0xFF121018), t.neonSecondary, 0.08)!
                    : Color.lerp(const Color(0xFF0C0614), t.neonSecondary, 0.28)!,
                topLeft: offlineExec
                    ? t.neonPrimary.withValues(alpha: 0.42)
                    : Color.lerp(t.neonPrimary, const Color(0xFFFFFFFF), 0.16)!,
                bottomRight: offlineExec
                    ? t.neonSecondary.withValues(alpha: 0.35)
                    : t.neonSecondary.withValues(alpha: 0.92),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '[ 发射 ]',
                    maxLines: 1,
                    softWrap: false,
                    style: PixelStyle.vt323(
                      fontSize: 12,
                      color: offlineExec
                          ? t.neonPrimary.withValues(alpha: 0.42)
                          : t.terminalAmber.withValues(alpha: 0.98),
                      shadows: offlineExec
                          ? null
                          : <Shadow>[
                              Shadow(color: accent.withValues(alpha: 0.95), blurRadius: 0, offset: const Offset(1, 0)),
                              Shadow(
                                color: t.neonSecondary.withValues(alpha: 0.72),
                                blurRadius: 0,
                                offset: const Offset(-1, 0),
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 像素风雷达示意（无 Material 图标），配色随房间主题霓虹走
class _RadarGlyphPainter extends CustomPainter {
  const _RadarGlyphPainter({required this.accent, required this.dim});

  final Color accent;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2 + 0.5;
    final Offset c = Offset(cx, cy);
    final double r = math.min(size.width, size.height) / 2 - 2;

    final Paint rim = Paint()
      ..color = dim.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(c, r, rim);

    final Paint cross = Paint()
      ..color = CyberPalette.terminalGreen.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), cross);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), cross);

    final Paint sweep = Paint()
      ..color = accent.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.88),
      -math.pi * 0.9,
      math.pi * 0.42,
      false,
      sweep,
    );

    final Paint blip = Paint()..color = CyberPalette.terminalGreen.withValues(alpha: 0.95);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx + r * 0.38, cy - r * 0.28), width: 3, height: 3), blip);
  }

  @override
  bool shouldRepaint(covariant _RadarGlyphPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.dim != dim;
}

class _SwitchingOverlay extends StatelessWidget {
  const _SwitchingOverlay({required this.roomId, required this.roomName, required this.tokens});

  final String roomId;
  final String roomName;
  final RoomThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.68),
        child: Center(
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.82,
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: tokens.neonPrimary.withValues(alpha: 0.6), width: 2),
              color: const Color(0xF2080A17),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '[ 正在切换频段至 SECTOR-$roomId ($roomName)... ]',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: CyberFonts.pixel, fontSize: 13, color: tokens.neonPrimary.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 8, backgroundColor: Color(0xCC000000)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChaosOverlay extends StatelessWidget {
  const _ChaosOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.34),
        child: Center(
          child: Text(
            '[ SIGNALYLOST ]',
            style: TextStyle(
              fontFamily: CyberFonts.pixel,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: const Color(0xFFECFEFF),
              shadows: const <Shadow>[
                Shadow(color: Color(0xF3FF3838), offset: Offset(-3, 0)),
                Shadow(color: Color(0xF300F0FF), offset: Offset(3, 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataWipeOverlay extends StatelessWidget {
  const _DataWipeOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF020208),
      child: Center(
        child: Text(
          'SECURE_ERASE · LOCAL_BUFFER_PURGE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: CyberFonts.pixel,
            fontSize: 14,
            letterSpacing: 4,
            color: const Color(0xFFECFDF5),
            shadows: const <Shadow>[
              Shadow(color: Color(0xD9FF3C3C), offset: Offset(-2, 0)),
              Shadow(color: Color(0xD900F0FF), offset: Offset(2, 0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarOverlay extends StatelessWidget {
  const _RadarOverlay({
    required this.roomName,
    required this.members,
    required this.onClose,
  });

  final String roomName;
  final List<String> members;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const Color line = Color(0xFF1E4A5C);
    return ColoredBox(
      color: const Color(0xF5000206),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              decoration: const BoxDecoration(
                color: Color(0xE0081018),
                border: Border(bottom: BorderSide(color: line, width: 1)),
              ),
              child: Row(
                children: <Widget>[
                  Text('>>', style: PixelStyle.vt323(fontSize: 11, color: CyberPalette.neonCyan.withValues(alpha: 0.85))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SCAN.EXE · $roomName',
                      style: PixelStyle.vt323(
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: const Color(0xD9A5F3FC),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '[ X ]',
                        style: PixelStyle.vt323(fontSize: 12, color: CyberPalette.neonCyan.withValues(alpha: 0.75)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        '[ 扫描完毕 · 未探测到其他终端 ]',
                        style: PixelStyle.vt323(fontSize: 12, color: CyberPalette.neonCyan.withValues(alpha: 0.45)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      itemCount: members.length,
                      itemBuilder: (BuildContext context, int i) {
                        final String name = members[i];
                        final String url =
                            'https://api.dicebear.com/9.x/pixel-art/svg?seed=${Uri.encodeComponent(name)}';
                        final String idx = (i + 1).toString().padLeft(2, '0');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF020508),
                              border: Border(
                                left: BorderSide(color: Color(0xFF2A4A58), width: 2),
                                top: BorderSide(color: Color(0xFF151820), width: 1),
                                right: BorderSide(color: Color(0xFF151820), width: 1),
                                bottom: BorderSide(color: Color(0xFF151820), width: 1),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    idx,
                                    style: PixelStyle.vt323(fontSize: 10, color: CyberPalette.terminalGreen.withValues(alpha: 0.5)),
                                  ),
                                ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A1018),
                                    border: Border.all(color: const Color(0xFF334455), width: 1),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.network(
                                    url,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        '?',
                                        style: PixelStyle.vt323(fontSize: 14, color: const Color(0xFF446688)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PixelStyle.vt323(fontSize: 13, color: const Color(0xF2E8F0FF)),
                                  ),
                                ),
                                Text(
                                  '[ON]',
                                  style: PixelStyle.vt323(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: CyberPalette.terminalGreen.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: PixButton(
                onTap: onClose,
                width: double.infinity,
                face: const Color(0xFFC0C0C0),
                topLeft: Colors.white,
                bottomRight: const Color(0xFF424242),
                child: Text('[ 关闭 ]', style: PixelStyle.vt323(fontSize: 14, color: const Color(0xFF000080))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
