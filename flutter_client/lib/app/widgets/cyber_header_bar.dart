import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/avatar_pool.dart';
import '../../core/storage/session_store.dart';
import '../../core/theme/pixel_style.dart';
import '../../core/theme/theme.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../widgets/ping_monitor.dart';
import '../../widgets/uptime_monitor.dart';
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

  // ── 兔子洞彩蛋 ──
  int _secretTapCount = 0;
  Timer? _secretTapTimer;

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
    _secretTapTimer?.cancel();
    super.dispose();
  }

  void _handleSecretTap() {
    _secretTapCount++;
    _secretTapTimer?.cancel();
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _secretTapTimer = null;
      // 关闭弹出菜单后触发彩蛋序列
      Navigator.of(context).pop();
      _triggerGlitchSequence();
    } else {
      _secretTapTimer = Timer(const Duration(milliseconds: 500), () {
        _secretTapCount = 0;
      });
    }
  }

  Future<void> _triggerGlitchSequence() async {
    if (!mounted) return;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final OverlayEntry glitch = OverlayEntry(
      builder: (_) => const _GlitchOverlay(),
    );
    overlay.insert(glitch);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    glitch.remove();
    if (!mounted) return;
    _showRabbitHoleDialog();
  }

  void _showRabbitHoleDialog() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: Duration.zero,
      pageBuilder: (BuildContext ctx, _, __) => const _RabbitHoleDialog(),
    );
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
        offset: const Offset(0, 6),
        color: const Color(0xF00B0F1E),
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(minWidth: 210, maxWidth: 240),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Color(0xFF2B3A58), width: 1),
        ),
        child: PixelAvatarShell(imageUrl: url, pixelEmoji: entry.pixelEmoji),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<Object?>>[
          _MenuInfoEntry(
            title: '当前赛博代号',
            value: widget.cyberName?.trim().isNotEmpty == true ? widget.cyberName!.trim() : 'ANON',
          ),
          _MenuInfoEntry(
            title: '神经接驳时长',
            valueWidget: const UptimeMonitor(),
            onTap: _handleSecretTap,
          ),
          const _MenuInfoEntry(
            title: '链路延迟监控',
            valueWidget: PingMonitor(),
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
          _EjectMenuActionEntry(
            onTap: _showEmergencyEjectConfirmDialog,
          ),
          _FormatCMenuActionEntry(
            onTap: _showFormatCDialog,
          ),
          const PopupMenuDivider(height: 1),
          _ReadMeMenuEntry(
            onTap: _showReadMeDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showReadMeDialog() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'readme',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: Duration.zero,
      pageBuilder: (BuildContext ctx, _, __) => const _ReadMeDialog(),
    );
  }

  Future<void> _showFormatCDialog() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: Duration.zero,
      pageBuilder: (BuildContext ctx, _, __) => _FormatCDialog(
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await _executeFormatC();
        },
        onAbort: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _executeFormatC() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    bool finished = false;

    Future<void> finish() async {
      if (finished) return;
      finished = true;
      entry.remove();
      widget.onLogout();
      if (!mounted) return;
      try {
        await Navigator.of(context).pushReplacementNamed('/');
      } catch (_) {}
    }

    entry = OverlayEntry(
      builder: (_) => _RedFlashOverlay(onFinished: finish),
    );
    overlay.insert(entry);
  }

  Future<void> _triggerEmergencyEject() async {
    debugPrint('WebSocket Ejected');
    if (!mounted) return;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    bool finished = false;

    Future<void> finishSequence() async {
      if (finished) return;
      finished = true;
      entry.remove();
      widget.onLogout();
      if (!mounted) return;
      try {
        await Navigator.of(context).pushReplacementNamed('/');
      } catch (_) {
        // Fallback: route table may not define named entries beyond home.
      }
    }

    entry = OverlayEntry(
      builder: (_) => _CrtShutdownOverlay(
        onFinished: finishSequence,
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _showEmergencyEjectConfirmDialog() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'eject_confirm',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (BuildContext dialogContext, _, __) {
        return Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A0A),
              border: Border(
                top: BorderSide(color: Colors.white, width: 2),
                left: BorderSide(color: Colors.white, width: 2),
                right: BorderSide(color: Color(0xFF2A0203), width: 2),
                bottom: BorderSide(color: Color(0xFF2A0203), width: 2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '确认紧急脱机？',
                  style: PixelStyle.vt323(
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '执行后将立刻断开当前会话。',
                  style: PixelStyle.vt323(
                    fontSize: 11,
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _ConfirmActionButton(
                      label: '[ 取消 ]',
                      onTap: () => Navigator.of(dialogContext).pop(),
                    ),
                    const SizedBox(width: 8),
                    _ConfirmActionButton(
                      label: '[ 确认脱机 ]',
                      danger: true,
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _triggerEmergencyEject();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    this.value,
    this.valueWidget,
    this.onTap,
  });

  final String title;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback? onTap;

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
    final Widget content = Padding(
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
          widget.valueWidget ??
              Text(
                widget.value ?? '',
                style: PixelStyle.vt323(fontSize: 12, color: const Color(0xFFE0F2FE), height: 1.2),
              ),
        ],
      ),
    );
    if (widget.onTap == null) return content;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
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

class _EjectMenuActionEntry extends PopupMenuEntry<Object?> {
  const _EjectMenuActionEntry({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  double get height => 44;

  @override
  bool represents(Object? value) => false;

  @override
  State<_EjectMenuActionEntry> createState() => _EjectMenuActionEntryState();
}

class _EjectMenuActionEntryState extends State<_EjectMenuActionEntry> {
  bool _pressed = false;

  BoxDecoration _decoration() {
    final bool p = _pressed;
    return BoxDecoration(
      color: p ? const Color(0xFF4A0608) : const Color(0xFF5D080A),
      border: Border(
        top: BorderSide(color: p ? const Color(0xFF2A0203) : Colors.white, width: 2),
        left: BorderSide(color: p ? const Color(0xFF2A0203) : Colors.white, width: 2),
        bottom: BorderSide(color: p ? Colors.white : const Color(0xFF2A0203), width: 2),
        right: BorderSide(color: p ? Colors.white : const Color(0xFF2A0203), width: 2),
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
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _handleTap,
        child: Container(
          decoration: _decoration(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            '紧急脱机',
            style: PixelStyle.vt323(
              fontSize: 11,
              color: Colors.white,
              letterSpacing: 1.1,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmActionButton extends StatefulWidget {
  const _ConfirmActionButton({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_ConfirmActionButton> createState() => _ConfirmActionButtonState();
}

class _ConfirmActionButtonState extends State<_ConfirmActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color base = widget.danger ? const Color(0xFF5D080A) : const Color(0xFF1B1B1B);
    final Color dark = widget.danger ? const Color(0xFF2A0203) : const Color(0xFF3A3A3A);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: base,
          border: Border(
            top: BorderSide(color: _pressed ? dark : Colors.white, width: 2),
            left: BorderSide(color: _pressed ? dark : Colors.white, width: 2),
            right: BorderSide(color: _pressed ? Colors.white : dark, width: 2),
            bottom: BorderSide(color: _pressed ? Colors.white : dark, width: 2),
          ),
        ),
        child: Text(
          widget.label,
          style: PixelStyle.vt323(
            fontSize: 11,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _CrtShutdownOverlay extends StatefulWidget {
  const _CrtShutdownOverlay({required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<_CrtShutdownOverlay> createState() => _CrtShutdownOverlayState();
}

class _CrtShutdownOverlayState extends State<_CrtShutdownOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scaleY;
  late final Animation<double> _scaleX;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _scaleY = Tween<double>(
      begin: 1.0,
      end: 0.012,
    ).animate(
      CurvedAnimation(
        parent: _ctl,
        curve: const Interval(0, 0.5, curve: Curves.easeInCubic),
      ),
    );
    _scaleX = TweenSequence<double>(
      <TweenSequenceItem<double>>[
        TweenSequenceItem<double>(tween: ConstantTween<double>(1.0), weight: 50),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 50,
        ),
      ],
    ).animate(_ctl);
    _ctl.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: AnimatedBuilder(
            animation: _ctl,
            builder: (_, __) {
              final double sx = _scaleX.value.clamp(0.0, 1.0);
              final double sy = _scaleY.value.clamp(0.0, 1.0);
              return Transform.scale(
                scaleX: sx,
                scaleY: sy,
                child: Container(
                  width: size.width * 1.1,
                  height: size.height * 0.9,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMAT C: 自毁程序 ─ 菜单项
// ─────────────────────────────────────────────────────────────────────────────

class _FormatCMenuActionEntry extends PopupMenuEntry<Object?> {
  const _FormatCMenuActionEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  double get height => 44;

  @override
  bool represents(Object? value) => false;

  @override
  State<_FormatCMenuActionEntry> createState() => _FormatCMenuActionEntryState();
}

class _FormatCMenuActionEntryState extends State<_FormatCMenuActionEntry> {
  bool _pressed = false;

  BoxDecoration _deco() {
    return BoxDecoration(
      color: Colors.black,
      border: Border.all(color: const Color(0xFFFF0000), width: _pressed ? 1 : 2),
    );
  }

  void _handleTap() {
    Navigator.of(context).pop<Object?>(null);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _handleTap,
        child: Container(
          decoration: _deco(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            '[ 自毁程序 ]',
            style: PixelStyle.vt323(
              fontSize: 11,
              color: const Color(0xFFFF0000),
              letterSpacing: 1.1,
              height: 1.2,
              shadows: const <Shadow>[
                Shadow(color: Color(0xFFFF0000), blurRadius: 10),
                Shadow(color: Color(0xFFFF0000), blurRadius: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMAT C: 自毁程序 ─ 命令行确认弹窗
// ─────────────────────────────────────────────────────────────────────────────

class _FormatCDialog extends StatefulWidget {
  const _FormatCDialog({required this.onConfirm, required this.onAbort});

  final Future<void> Function() onConfirm;
  final VoidCallback onAbort;

  @override
  State<_FormatCDialog> createState() => _FormatCDialogState();
}

const String _kFormatWarning =
    'WARNING: This will erase all local\n'
    'cyber-traces and device fingerprints.\n'
    '\n'
    '警告：此操作将抹除本地所有\n'
    '赛博痕迹与设备指纹。\n'
    '\n'
    'Proceed with format? [Y/N] ';

class _FormatCDialogState extends State<_FormatCDialog> {
  final String _full = _kFormatWarning;
  String _shown = '';
  bool _cursorOn = true;
  bool _typingDone = false;
  bool _executing = false;
  Timer? _typeTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _startTyping();
    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 530),
      (_) { if (mounted) setState(() => _cursorOn = !_cursorOn); },
    );
  }

  void _startTyping() {
    int idx = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      if (!mounted) { _typeTimer?.cancel(); return; }
      if (idx < _full.length) {
        setState(() => _shown = _full.substring(0, idx + 1));
        idx++;
      } else {
        _typeTimer?.cancel();
        setState(() => _typingDone = true);
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  TextStyle get _termStyle => PixelStyle.vt323(
    fontSize: 13,
    color: CyberPalette.terminalGreen,
    height: 1.55,
    shadows: const <Shadow>[
      Shadow(color: CyberPalette.terminalGreen, blurRadius: 6),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final String cursor = _cursorOn ? '_' : ' ';
    return Material(
      color: Colors.black,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'C:\\SYSTEM\\FORMAT.EXE',
                style: PixelStyle.vt323(
                  fontSize: 11,
                  color: CyberPalette.terminalGreen.withValues(alpha: 0.55),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: CyberPalette.terminalGreen.withValues(alpha: 0.3)),
              const SizedBox(height: 24),
              Text('$_shown$cursor', style: _termStyle),
              const Spacer(),
              if (_typingDone && !_executing) ...<Widget>[
                Container(height: 1, color: CyberPalette.terminalGreen.withValues(alpha: 0.3)),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    _TermButton(
                      label: '[ Y_EXECUTE ]',
                      color: const Color(0xFFFF2222),
                      onTap: () async {
                        setState(() => _executing = true);
                        await widget.onConfirm();
                      },
                    ),
                    const SizedBox(width: 24),
                    _TermButton(
                      label: '[ N_ABORT ]',
                      color: CyberPalette.terminalGreen,
                      onTap: widget.onAbort,
                    ),
                  ],
                ),
              ],
              if (_executing)
                Text(
                  'EXECUTING FORMAT C: ...',
                  style: PixelStyle.vt323(
                    fontSize: 13,
                    color: const Color(0xFFFF2222),
                    shadows: const <Shadow>[Shadow(color: Color(0xFFFF2222), blurRadius: 10)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermButton extends StatefulWidget {
  const _TermButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_TermButton> createState() => _TermButtonState();
}

class _TermButtonState extends State<_TermButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hover = true),
      onTapUp: (_) => setState(() => _hover = false),
      onTapCancel: () => setState(() => _hover = false),
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _hover ? widget.color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: widget.color.withValues(alpha: _hover ? 1.0 : 0.7), width: 1),
        ),
        child: Text(
          widget.label,
          style: PixelStyle.vt323(
            fontSize: 13,
            color: widget.color,
            letterSpacing: 1.0,
            shadows: <Shadow>[Shadow(color: widget.color, blurRadius: _hover ? 12 : 6)],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMAT C: 自毁程序 ─ 全屏红色闪烁 Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _RedFlashOverlay extends StatefulWidget {
  const _RedFlashOverlay({required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<_RedFlashOverlay> createState() => _RedFlashOverlayState();
}

class _RedFlashOverlayState extends State<_RedFlashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  // 3 快速红白交替闪，再渐黑
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _opacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.0, end: 0.85), weight: 10),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.85, end: 0.2), weight: 10),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.2, end: 0.9), weight: 10),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.9, end: 0.15), weight: 10),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.15, end: 1.0), weight: 20),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1.0), weight: 40),
    ]).animate(_ctl);
    _ctl.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) widget.onFinished();
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) {
          final double t = _ctl.value;
          // 前 60%: 红色闪烁；后 40%: 全黑
          final Color color = t < 0.6 ? const Color(0xFFFF0000) : Colors.black;
          return ColoredBox(
            color: color.withValues(alpha: _opacity.value),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 兔子洞彩蛋 ─ 信号故障 Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _GlitchOverlay extends StatefulWidget {
  const _GlitchOverlay();

  @override
  State<_GlitchOverlay> createState() => _GlitchOverlayState();
}

class _GlitchOverlayState extends State<_GlitchOverlay> {
  final Random _rng = Random();
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (mounted) setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _GlitchPainter(_rng, _frame),
        ),
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  _GlitchPainter(this._rng, this._frame);

  final Random _rng;
  final int _frame;

  static const List<Color> _colors = <Color>[
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFFFF00),
    Color(0xFF00FFFF),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );
    final int strips = 6 + _rng.nextInt(14);
    for (int i = 0; i < strips; i++) {
      final double y = _rng.nextDouble() * size.height;
      final double h = 1.5 + _rng.nextDouble() * 22;
      final double x = _rng.nextDouble() * size.width * 0.35;
      final double w = size.width * (0.25 + _rng.nextDouble() * 0.75);
      final Color base = _colors[_rng.nextInt(_colors.length)];
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()..color = base.withValues(alpha: 0.25 + _rng.nextDouble() * 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(_GlitchPainter old) => old._frame != _frame;
}

// ─────────────────────────────────────────────────────────────────────────────
// 兔子洞彩蛋 ─ 血色警告弹窗
// ─────────────────────────────────────────────────────────────────────────────

class _RabbitHoleDialog extends StatelessWidget {
  const _RabbitHoleDialog();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.red, width: 3),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0xAAFF0000), blurRadius: 24, spreadRadius: 4),
              BoxShadow(color: Color(0x44FF0000), blurRadius: 56, spreadRadius: 12),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '[ UNAUTHORIZED ACCESS DETECTED ]',
                style: PixelStyle.vt323(
                  fontSize: 12,
                  color: Colors.red,
                  letterSpacing: 1.0,
                  height: 1.3,
                  shadows: const <Shadow>[Shadow(color: Colors.red, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connection to Root Server established...\n'
                'Operator is listening.\n'
                '\n'
                'Drop payload to: support@dothings.one',
                style: PixelStyle.vt323(
                  fontSize: 12,
                  color: Colors.red,
                  height: 1.65,
                  shadows: const <Shadow>[Shadow(color: Colors.red, blurRadius: 6)],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: Text(
                    '[ DISCONNECT ]',
                    style: PixelStyle.vt323(
                      fontSize: 12,
                      color: Colors.black,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ_ME.TXT ─ 菜单入口 & 宣言弹窗
// ─────────────────────────────────────────────────────────────────────────────

class _ReadMeMenuEntry extends PopupMenuEntry<Object?> {
  const _ReadMeMenuEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  double get height => 48;

  @override
  bool represents(Object? value) => false;

  @override
  State<_ReadMeMenuEntry> createState() => _ReadMeMenuEntryState();
}

class _ReadMeMenuEntryState extends State<_ReadMeMenuEntry> {
  bool _hover = false;

  void _handleTap() {
    Navigator.of(context).pop<Object?>(null);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _hover = true),
      onTapCancel: () => setState(() => _hover = false),
      onTapUp: (_) => setState(() => _hover = false),
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Text(
          '[ READ_ME.TXT ]',
          style: PixelStyle.vt323(
            fontSize: 11,
            color: _hover
                ? const Color(0xFF6B7280)
                : const Color(0xFF4B5563),
            letterSpacing: 0.8,
            height: 1.2,
          ).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _ReadMeDialog extends StatelessWidget {
  const _ReadMeDialog();

  // TODO: replace 'support@dothings.one' with final contact email if it changes
  static const String _body =
      '// PROJECT: 2000.EXE\n'
      '// STATUS: ONLINE\n'
      '// ARCHITECT: [CYBER_MONKEY]\n'
      '\n'
      'If you are reading this, the system is alive.\n'
      'This space is unmonitored. Be water.\n'
      '\n'
      'To establish a direct neural link with the Architect\n'
      'for collaboration or business:\n'
      '>> ping -t support@dothings.one';

  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: 'PixelFont',
    fontSize: 13,
    color: Color(0xFF39FF14),
    height: 1.65,
    letterSpacing: 0.3,
    shadows: <Shadow>[
      Shadow(color: Color(0xFF39FF14), blurRadius: 6),
    ],
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: const Color(0xFF374151), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: const Color(0xFF111827),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'C:\\USERS\\ANON\\READ_ME.TXT',
                          style: PixelStyle.vt323(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          '[ CLOSE_FILE ]',
                          style: PixelStyle.vt323(
                            fontSize: 11,
                            color: const Color(0xFF4B5563),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: const Color(0xFF1F2937)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Text(_body, style: _bodyStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
