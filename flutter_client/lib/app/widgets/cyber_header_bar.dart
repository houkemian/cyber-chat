import 'dart:math';

import 'package:flutter/material.dart';

import '../constants/avatar_pool.dart';
import '../../core/storage/session_store.dart';
import '../../core/theme/pixel_style.dart';
import '../../core/theme/theme.dart';
import '../../features/auth/data/auth_repository.dart';
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

class _CyberHeaderBarState extends State<CyberHeaderBar> with TickerProviderStateMixin {
  late final AnimationController _neonCtl;
  late final AnimationController _rivetBlinkCtl;

  @override
  void initState() {
    super.initState();
    _neonCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    _rivetBlinkCtl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _neonCtl.dispose();
    _rivetBlinkCtl.dispose();
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

    final Widget headerPanel = _buildHeaderPanel(row, dense: widget.embeddedInCard);

    if (widget.embeddedInCard) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(padding: pad, child: headerPanel),
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

    return Padding(
      padding: pad,
      child: headerPanel,
    );
  }

  Widget _buildHeaderPanel(Widget row, {required bool dense}) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, dense ? 10 : 12, 12, dense ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D18),
        border: Border(
          top: BorderSide(color: const Color(0xFF2B3A58).withValues(alpha: 0.95), width: 2),
          left: BorderSide(color: const Color(0xFF2B3A58).withValues(alpha: 0.95), width: 2),
          bottom: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.52), width: 2),
          right: BorderSide(color: CyberPalette.neonPurple.withValues(alpha: 0.42), width: 2),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0x221C2F52),
                      Colors.transparent,
                      const Color(0x22140D22),
                    ],
                    stops: const <double>[0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HeaderScanlinePainter(),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 2,
            child: AnimatedBuilder(
              animation: _rivetBlinkCtl,
              builder: (BuildContext context, Widget? child) {
                final bool blinkOn = _rivetBlinkCtl.value < 0.5;
                return Row(
                  children: <Widget>[
                    _HeaderRivet(active: blinkOn),
                    const SizedBox(width: 6),
                    _HeaderRivet(active: blinkOn),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: row,
          ),
        ],
      ),
    );
  }

  /// 与 Web `--chat-panel-r-inset` 对齐（头像右缘与下方聊天面板右边框）。
  double get _chatPanelRightInset => 14 + 3 + 2 + 2;

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
          _MenuInfoEntry(
            title: '当前赛博代号',
            value: widget.cyberName?.trim().isNotEmpty == true ? widget.cyberName!.trim() : 'ANON',
          ),
          const _MenuInfoEntry(
            title: '在线驻留时长',
            value: 'UPLINK --:--:--',
          ),
          const PopupMenuDivider(height: 1),
          _CyberMenuActionEntry(
            label: '[ 伪造新身份 ]',
            onTap: _showForgeIdentityDialog,
          ),
          _CyberMenuActionEntry(
            label: '[ 身份重构模块 ]',
            onTap: _showIdentityModule,
          ),
          _CyberMenuActionEntry(
            label: '[ 终止当前进程 ]',
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }

  Future<void> _showForgeIdentityDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (BuildContext ctx) {
        return _ForgeIdentityDialog(
          currentCyberName: widget.cyberName,
          onSaved: (String newCyberName) async {
            await widget.onIdentityForged(newCyberName);
          },
        );
      },
    );
  }

  Future<void> _showIdentityModule() async {
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

class _HeaderScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0xFF111827).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (double y = 1; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderScanlinePainter oldDelegate) => false;
}

class _HeaderRivet extends StatelessWidget {
  const _HeaderRivet({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7EEBFF) : const Color(0xFF4B5568),
        border: Border.all(color: const Color(0xFF111827), width: 1),
      ),
    );
  }
}

class _MenuInfoEntry extends PopupMenuEntry<Object?> {
  const _MenuInfoEntry({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  double get height => 46;

  @override
  bool represents(Object? value) => false;

  @override
  State<_MenuInfoEntry> createState() => _MenuInfoEntryState();
}

class _MenuInfoEntryState extends State<_MenuInfoEntry> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '>> ${widget.title}:',
            style: PixelStyle.vt323(fontSize: 11, color: const Color(0xFF99F6E4), height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            widget.value,
            style: PixelStyle.vt323(fontSize: 12, color: const Color(0xFFE0F2FE), height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _ForgeIdentityDialog extends StatefulWidget {
  const _ForgeIdentityDialog({
    required this.currentCyberName,
    required this.onSaved,
  });

  final String? currentCyberName;
  final Future<void> Function(String newCyberName) onSaved;

  @override
  State<_ForgeIdentityDialog> createState() => _ForgeIdentityDialogState();
}

class _ForgeIdentityDialogState extends State<_ForgeIdentityDialog> {
  String? _previewName;
  int? _remainingAttempts;
  bool _busy = true;
  bool _saving = false;
  String? _errorText;
  late final AuthRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AuthRepository();
    _previewName = widget.currentCyberName;
    _bootstrapPreview();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  Future<void> _bootstrapPreview() async {
    await _regenerate();
  }

  Future<void> _regenerate() async {
    if (_saving) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final String? token = await SessionStore.readToken();
      if (token == null || token.isEmpty) {
        throw AuthRepositoryException('未登录');
      }
      final ForgeIdentityPreview preview = await _repo.forgeIdentityPreview(token: token);
      if (!mounted) return;
      setState(() {
        _previewName = preview.cyberName;
        _remainingAttempts = preview.remainingAttempts;
      });
    } on AuthRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '昵称重构失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    final String candidate = (_previewName ?? '').trim();
    if (candidate.isEmpty || _saving || _busy) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final String? token = await SessionStore.readToken();
      if (token == null || token.isEmpty) {
        throw AuthRepositoryException('未登录');
      }
      final AuthResult r = await _repo.saveForgedIdentity(
        token: token,
        cyberName: candidate,
      );
      await SessionStore.saveSession(token: r.token, cyberName: r.cyberName);
      await widget.onSaved(r.cyberName);
      if (mounted) Navigator.of(context).pop();
    } on AuthRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '保存失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = _previewName ?? 'ANON';
    final String remainText = _remainingAttempts == null ? '--' : '$_remainingAttempts';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
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
              '伪造新身份',
              style: PixelStyle.vt323(fontSize: 14, color: CyberPalette.neonCyan, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '可重新生成昵称并保存，当前总上限 999 次',
              style: PixelStyle.vt323(fontSize: 11, color: CyberPalette.terminalGreen.withValues(alpha: 0.58)),
            ),
            const SizedBox(height: 14),
            Text(
              '候选昵称',
              style: PixelStyle.vt323(fontSize: 11, color: const Color(0xFF99F6E4)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                border: Border.all(color: CyberPalette.neonPurple.withValues(alpha: 0.55)),
              ),
              child: Text(
                displayName,
                style: PixelStyle.vt323(fontSize: 13, color: const Color(0xFFE0F2FE)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '剩余重构次数: $remainText',
              style: PixelStyle.vt323(fontSize: 11, color: const Color(0xFFB7F9D0)),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: PixelStyle.vt323(fontSize: 11, color: const Color(0xFFFF7B7B)),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                PixButton(
                  onTap: _busy ? null : _regenerate,
                  enabled: !_busy && !_saving,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  face: const Color(0xFF0A1218),
                  topLeft: CyberPalette.neonPurple.withValues(alpha: 0.65),
                  bottomRight: const Color(0xFF1A1020),
                  child: Text(
                    _busy ? '[ 生成中... ]' : '[ 重新生成昵称 ]',
                    style: PixelStyle.vt323(fontSize: 11, color: CyberPalette.neonCyan),
                  ),
                ),
                PixButton(
                  onTap: (_busy || _saving) ? null : _save,
                  enabled: !_busy && !_saving,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  face: const Color(0xFF140A1C),
                  topLeft: CyberPalette.neonCyan.withValues(alpha: 0.75),
                  bottomRight: CyberPalette.neonPurple.withValues(alpha: 0.65),
                  child: Text(
                    _saving ? '[ 保存中... ]' : '[ 保存昵称 ]',
                    style: PixelStyle.vt323(fontSize: 12, color: CyberPalette.terminalGreen),
                  ),
                ),
                PixButton(
                  onTap: (_busy || _saving) ? null : () => Navigator.of(context).pop(),
                  enabled: !_busy && !_saving,
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

class _CyberMenuActionEntry extends PopupMenuEntry<Object?> {
  const _CyberMenuActionEntry({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  double get height => 42;

  @override
  bool represents(Object? value) => false;

  @override
  State<_CyberMenuActionEntry> createState() => _CyberMenuActionEntryState();
}

class _CyberMenuActionEntryState extends State<_CyberMenuActionEntry> {
  bool _pressed = false;

  BoxDecoration _decoration(bool pressed) {
    final Color strokeA = pressed ? const Color(0xFF00B8D9) : const Color(0xFF00F0FF);
    final Color strokeB = pressed ? const Color(0xFF7A11C8) : const Color(0xFFBC00FF);
    final Color fillA = pressed ? const Color(0xFF1A1230) : const Color(0xFF1E1438);
    final Color fillB = pressed ? const Color(0xFF0B0F1E) : const Color(0xFF101A2F);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[fillA, fillB],
      ),
      border: Border.all(color: strokeA, width: 1.5),
      boxShadow: <BoxShadow>[
        BoxShadow(color: strokeA.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 0),
        BoxShadow(color: strokeB.withValues(alpha: 0.45), blurRadius: 0, spreadRadius: 0, offset: const Offset(1, 1)),
      ],
    );
  }

  TextStyle _labelStyle(bool pressed) {
    return PixelStyle.vt323(
      fontSize: 11,
      height: 1.2,
      color: pressed ? const Color(0xFFE6F7FF) : const Color(0xFFB9F7FF),
      letterSpacing: 1.0,
      shadows: <Shadow>[
        Shadow(
          color: (pressed ? const Color(0xFF00D8FF) : const Color(0xFF00F0FF)).withValues(alpha: 0.8),
          blurRadius: 0,
          offset: const Offset(1, 0),
        ),
      ],
    );
  }

  Widget _buildScanlineOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.12),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.04),
            ],
            stops: const <double>[0, 0.5, 1],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    Navigator.of(context).pop<Object?>(null);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _handleTap,
        child: Container(
          decoration: _decoration(_pressed),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _buildScanlineOverlay()),
              Text(
                widget.label,
                style: _labelStyle(_pressed),
              ),
            ],
          ),
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
