import 'package:flutter/material.dart';

import '../constants/avatar_pool.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/theme/pixel_style.dart';
import '../../core/theme/theme.dart';
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
    required this.onShowQr,
    required this.onPinToHome,
  });

  /// 为 true 时不绘制独立圆角卡片（由外层统一卡片包住），仅保留底部分隔。
  final bool embeddedInCard;

  final bool loggedIn;
  final String? cyberName;
  final int avatarIdx;
  final VoidCallback onTeleport;
  final VoidCallback onLogout;
  final VoidCallback onShowQr;
  final VoidCallback onPinToHome;

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

  Widget _buildAvatarMenu() {
    final idx = widget.avatarIdx.clamp(0, kAvatarPool.length - 1);
    final entry = kAvatarPool[idx];
    final seed = entry.seed == '__NAME__' ? (widget.cyberName?.trim().isNotEmpty == true ? widget.cyberName! : 'midnight') : entry.seed;
    final url = dicebearPixelArtPngUrl(seed, size: 192);

    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        offset: const Offset(0, 8),
        color: const Color(0xE80E1638),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.55)),
        ),
        child: PixelAvatarShell(imageUrl: url),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            child: DefaultTextStyle(
              style: PixelStyle.vt323(fontSize: 12, color: const Color(0xFF99F6E4), height: 1.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('>> 当前身份密匙 (Uplink Key):'),
                  Text(widget.cyberName ?? 'ANON', style: const TextStyle(color: Color(0xFFE0F2FE))),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'pin',
            child: Text('部署到主屏幕 (Pin to Home)', style: PixelStyle.vt323(fontSize: 12)),
          ),
          PopupMenuItem<String>(
            value: 'qr',
            child: Text('下载移动端矩阵 (Scan QR)', style: PixelStyle.vt323(fontSize: 12)),
          ),
          PopupMenuItem<String>(
            value: 'out',
            child: Text('终止当前进程 (Terminate PID)', style: PixelStyle.vt323(fontSize: 12)),
          ),
        ],
        onSelected: (String value) {
          if (value == 'pin') widget.onPinToHome();
          if (value == 'qr') widget.onShowQr();
          if (value == 'out') widget.onLogout();
        },
      ),
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

/// 简单二维码说明弹窗（对应 Web 扫码下载说明）。
Future<void> showCyberQrDialog(BuildContext context) async {
  final base = ApiEndpoints.httpBaseUrl;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xF5070E24),
      title: const Text('[ APP UPLINK PORTAL ]', style: TextStyle(fontFamily: 'Courier', fontSize: 15, letterSpacing: 2)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '扫描量子码，将 2000.exe 同步到你的移动终端。',
              style: TextStyle(fontSize: 12, color: Color(0xFFC4B5FD)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(base)}',
                width: 240,
                height: 240,
                errorBuilder: (_, __, ___) => const Text('[ QR 加载失败 ]', style: TextStyle(color: Color(0xFF93C5FD))),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(base, style: const TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
      ],
    ),
  );
}
