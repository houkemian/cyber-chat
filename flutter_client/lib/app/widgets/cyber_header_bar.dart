import 'dart:math';

import 'package:flutter/material.dart';

import '../constants/avatar_pool.dart';
import '../../core/storage/session_store.dart';
import '../../core/theme/pixel_style.dart';
import '../../core/theme/theme.dart';
import '../../features/auth/data/auth_repository.dart';
import 'forge_identity_menu.dart';
import 'pix_button.dart';
import 'pixel_avatar_shell.dart';

/// 对应 Web `App.tsx` 顶栏：`.header` + slogan + `2000.exe` + 传送按钮 / 头像下拉。
class CyberHeaderBar extends StatefulWidget {
  const CyberHeaderBar({
    super.key,
    this.embeddedInCard = false,
    required this.loggedIn,
    required this.cyberName,
    required this.avatarIdx,
    required this.onTeleport,
    required this.onLogout,
    required this.onAvatarIdxSaved,
    required this.onIdentityForged,
  });

  /// 为 true 时不绘制独立圆角卡片（由外层统一卡片包住），仅保留底部分隔。
  final bool embeddedInCard;

  final bool loggedIn;
  final String? cyberName;
  final int avatarIdx;
  final VoidCallback onTeleport;
  final VoidCallback onLogout;
  /// 身份重构弹窗内保存新头像池下标（持久化由调用方负责）。
  final Future<void> Function(int idx) onAvatarIdxSaved;

  /// 「伪造新身份」成功后由 [SessionStore] 已写入新 token/网名，此处仅刷新 UI（如重建聊天会话）。
  final Future<void> Function(String newCyberName) onIdentityForged;

  @override
  State<CyberHeaderBar> createState() => _CyberHeaderBarState();
}

class _CyberHeaderBarState extends State<CyberHeaderBar> with SingleTickerProviderStateMixin {
  late final AnimationController _neonCtl;

  @override
  void initState() {
    super.initState();
    _neonCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
  }

  @override
  void dispose() {
    _neonCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w <= 480;
    final scale = 0.825;

    final EdgeInsets pad = EdgeInsets.fromLTRB(
      16 * scale,
      16 * scale,
      widget.embeddedInCard ? 16 * scale : _chatPanelRightInset,
      widget.embeddedInCard ? 12 * scale : 16 * scale,
    );

    final Widget row = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!isNarrow)
                  Text(
                    '禁止实名，允许发疯。',
                    style: PixelStyle.vt323(
                      fontSize: (12 * scale).roundToDouble(),
                      letterSpacing: 2,
                      color: CyberPalette.neonCyan.withValues(alpha: 0.88),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _neonCtl,
                      builder: (context, child) {
                        final v = 0.82 + 0.18 * (1 - (_neonCtl.value - 0.2).abs().clamp(0.0, 1.0));
                        return Opacity(
                          opacity: v.clamp(0.78, 1.0),
                          child: child,
                        );
                      },
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect b) {
                          return const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFFFFFBFF),
                              Color(0xFFF5D0FE),
                              Color(0xFFE9D5FF),
                              Color(0xFFC4B5FD),
                            ],
                          ).createShader(b);
                        },
                        child: Text(
                          '2000.exe',
                          style: PixelStyle.vt323(
                            fontSize: (26 * scale).clamp(18.0, 26.0),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                            height: 1.15,
                            color: Colors.white,
                            shadows: const <Shadow>[
                              Shadow(color: Color(0xFF00F0FF), blurRadius: 0, offset: Offset(1, 0)),
                              Shadow(color: Color(0xFFBC00FF), blurRadius: 0, offset: Offset(-1, 0)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isNarrow) ...<Widget>[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '禁止实名，允许发疯。',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PixelStyle.vt323(
                            fontSize: 11,
                            color: CyberPalette.neonCyan.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.loggedIn) _buildAvatarMenu() else _buildTeleportButton(),
        ],
      );

    if (widget.embeddedInCard) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(padding: pad, child: row),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0x0000F0FF),
                    Color(0xDD00F0FF),
                    Color(0xEEFF2EE6),
                    Color(0xDDBC00FF),
                    Color(0x00BC00FF),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1C1430),
            Color(0xFF100818),
            Color(0xFF140C24),
          ],
        ),
        border: Border.all(color: CyberPalette.neonCyan.withValues(alpha: 0.45)),
      ),
      child: row,
    );
  }

  /// 与 Web `--chat-panel-r-inset` 对齐（头像右缘与下方聊天面板右边框）。
  double get _chatPanelRightInset => 14 + 3 + 2 + 2;

  Future<void> _forgeIdentityFromMenu() async {
    final String? token = await SessionStore.readToken();
    if (token == null || token.isEmpty) {
      throw AuthRepositoryException('未登录');
    }
    final AuthRepository repo = AuthRepository();
    try {
      final AuthResult r = await repo.forgeIdentity(token: token);
      await SessionStore.saveSession(token: r.token, cyberName: r.cyberName);
      await widget.onIdentityForged(r.cyberName);
    } finally {
      repo.dispose();
    }
  }

  Widget _buildAvatarMenu() {
    final idx = widget.avatarIdx.clamp(0, kAvatarPool.length - 1);
    final entry = kAvatarPool[idx];
    final String? url = dicebearUrlForPoolEntry(entry, widget.cyberName, size: 192);

    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<Object?>(
        offset: const Offset(0, 8),
        color: const Color(0xE80E1638),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.55)),
        ),
        child: PixelAvatarShell(imageUrl: url, pixelEmoji: entry.pixelEmoji),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<Object?>>[
          IdentityForgeMenuEntry(
            cyberName: widget.cyberName,
            onForge: _forgeIdentityFromMenu,
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<Object?>(
            value: 'identity',
            child: Text('身份重构模块 (Identity)', style: PixelStyle.vt323(fontSize: 12)),
          ),
          PopupMenuItem<Object?>(
            value: 'out',
            child: Text('终止当前进程 (Terminate PID)', style: PixelStyle.vt323(fontSize: 12)),
          ),
        ],
        onSelected: (Object? value) {
          if (value == 'identity') {
            _showIdentityModule(context);
          }
          if (value == 'out') widget.onLogout();
        },
      ),
    );
  }

  Future<void> _showIdentityModule(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (BuildContext ctx) {
        return _IdentityRefactorDialog(
          cyberName: widget.cyberName,
          initialIdx: widget.avatarIdx,
          onSave: (int idx) async {
            await widget.onAvatarIdxSaved(idx);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Widget _buildTeleportButton() {
    return PixButton(
      onTap: widget.onTeleport,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      face: const Color(0xFF140014),
      topLeft: const Color(0xFFFF55FF),
      bottomRight: const Color(0xFF440044),
      child: Text(
        '[ 传送：GO! ]',
        style: PixelStyle.vt323(
          fontSize: 12,
          color: const Color(0xFFFF00FF),
          letterSpacing: 1,
          shadows: const <Shadow>[
            Shadow(color: Color(0xFFFF00FF), blurRadius: 0, offset: Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}

/// 从头像池随机「重新生成」预览，确认后由 [onSave] 写回。
class _IdentityRefactorDialog extends StatefulWidget {
  const _IdentityRefactorDialog({
    required this.cyberName,
    required this.initialIdx,
    required this.onSave,
  });

  final String? cyberName;
  final int initialIdx;
  final Future<void> Function(int idx) onSave;

  @override
  State<_IdentityRefactorDialog> createState() => _IdentityRefactorDialogState();
}

class _IdentityRefactorDialogState extends State<_IdentityRefactorDialog> {
  late int _previewIdx;
  final Random _rng = Random();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _previewIdx = widget.initialIdx.clamp(0, kAvatarPool.length - 1);
  }

  void _regenerate() {
    if (kAvatarPool.length <= 1) return;
    setState(() {
      int next = _previewIdx;
      for (int k = 0; k < 32; k++) {
        next = _rng.nextInt(kAvatarPool.length);
        if (next != _previewIdx) break;
      }
      _previewIdx = next;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_previewIdx);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AvatarPoolEntry entry = kAvatarPool[_previewIdx.clamp(0, kAvatarPool.length - 1)];
    final String? previewUrl = dicebearUrlForPoolEntry(entry, widget.cyberName, size: 192);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xF5081018),
          border: Border.all(color: CyberPalette.neonCyan.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '身份重构模块 (Identity)',
              style: PixelStyle.vt323(fontSize: 14, color: CyberPalette.neonCyan, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '从像素身份池随机重构 · 保存后同步顶栏头像',
              style: PixelStyle.vt323(fontSize: 11, color: CyberPalette.terminalGreen.withValues(alpha: 0.58)),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 80,
                height: 80,
                child: PixelAvatarShell(imageUrl: previewUrl, pixelEmoji: entry.pixelEmoji, edgePx: 76),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                PixButton(
                  onTap: _regenerate,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  face: const Color(0xFF0A1218),
                  topLeft: CyberPalette.neonPurple.withValues(alpha: 0.65),
                  bottomRight: const Color(0xFF1A1020),
                  child: Text('[ 重新生成 ]', style: PixelStyle.vt323(fontSize: 11, color: CyberPalette.neonCyan)),
                ),
                PixButton(
                  onTap: _saving ? null : _save,
                  enabled: !_saving,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  face: const Color(0xFF140A1C),
                  topLeft: CyberPalette.neonCyan.withValues(alpha: 0.75),
                  bottomRight: CyberPalette.neonPurple.withValues(alpha: 0.65),
                  child: Text(
                    _saving ? '[ ... ]' : '[ 保存 ]',
                    style: PixelStyle.vt323(fontSize: 12, color: CyberPalette.terminalGreen),
                  ),
                ),
                PixButton(
                  onTap: _saving ? null : () => Navigator.of(context).pop(),
                  enabled: !_saving,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  face: const Color(0xFF151018),
                  topLeft: const Color(0xFF553366),
                  bottomRight: const Color(0xFF220022),
                  child: Text('[ 关闭 ]', style: PixelStyle.vt323(fontSize: 12, color: const Color(0xFF8899AA))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
