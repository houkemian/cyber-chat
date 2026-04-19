import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'pixel_emoji_avatar.dart';

/// 对齐 H5 头像壳 + CRT 扫描线 + 轻噪点；全直角、硬边投影（无模糊光晕）。
///
/// [imageUrl] 与 [pixelEmoji] 二选一：DiceBear 网络图 **或** 像素栅格化 Emoji。
class PixelAvatarShell extends StatefulWidget {
  PixelAvatarShell({
    super.key,
    this.imageUrl,
    this.pixelEmoji,
    this.edgePx = 40,
  }) : assert(
          (imageUrl != null && imageUrl.isNotEmpty) != (pixelEmoji != null && pixelEmoji.trim().isNotEmpty),
        );

  final String? imageUrl;
  final String? pixelEmoji;
  final double edgePx;

  @override
  State<PixelAvatarShell> createState() => _PixelAvatarShellState();
}

class _PixelAvatarShellState extends State<PixelAvatarShell> with SingleTickerProviderStateMixin {
  late final AnimationController _grain;

  @override
  void initState() {
    super.initState();
    _grain = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..repeat();
  }

  @override
  void dispose() {
    _grain.dispose();
    super.dispose();
  }

  static const List<Offset> _grainOffsets = <Offset>[
    Offset.zero,
    Offset(-1, 1),
    Offset(1, -1),
    Offset(1, 1),
  ];

  Widget _baseRaster(double innerPx) {
    final String? emoji = widget.pixelEmoji?.trim();
    if (emoji != null && emoji.isNotEmpty) {
      return PixelatedEmojiAvatar(emoji: emoji, size: innerPx, showFrame: false);
    }
    return Image.network(
      widget.imageUrl!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      cacheWidth: 192,
      cacheHeight: 192,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xCC11152D)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.edgePx;
    final double innerPx = (s - 2).clamp(8.0, 512.0);

    return AnimatedBuilder(
      animation: _grain,
      builder: (BuildContext context, _) {
        final int grainIdx = (_grain.value * 4).floor() % 4;
        final double nudge = grainIdx.isOdd ? 0.5 : 0;
        return Transform.translate(
          offset: Offset(nudge, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // 硬边投影：纯色块错位，无 blur / spread
              Positioned(
                left: 3,
                top: 3,
                child: SizedBox(
                  width: s + 2,
                  height: s + 2,
                  child: const ColoredBox(color: Color(0xE6000000)),
                ),
              ),
              SizedBox(
                width: s + 2,
                height: s + 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF080A12),
                    border: Border(
                      top: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.88), width: 1),
                      left: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.88), width: 1),
                      bottom: BorderSide(color: CyberPalette.neonPurple.withValues(alpha: 0.75), width: 1),
                      right: BorderSide(color: CyberPalette.neonPurple.withValues(alpha: 0.75), width: 1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _baseRaster(innerPx),
                          const Positioned.fill(child: CustomPaint(painter: _CrtScanlineMaskPainter())),
                          Positioned.fill(
                            child: Transform.translate(
                              offset: _grainOffsets[grainIdx],
                              child: const Opacity(
                                opacity: 0.38,
                                child: CustomPaint(painter: _PixelDitherNoisePainter()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrtScanlineMaskPainter extends CustomPainter {
  const _CrtScanlineMaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0x38000000)
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y <= size.height; y += 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 稀疏棋盘格噪点，避免径向渐变带来的「柔光」感
class _PixelDitherNoisePainter extends CustomPainter {
  const _PixelDitherNoisePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..isAntiAlias = false
      ..color = const Color(0x18FFFFFF);
    const double step = 4;
    for (double y = 0; y < size.height; y += step) {
      final int row = (y / step).round();
      for (double x = row.isOdd ? 0 : step / 2; x < size.width; x += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
      }
    }
    final Paint q = Paint()
      ..isAntiAlias = false
      ..color = CyberPalette.neonPurple.withValues(alpha: 0.12);
    for (double y = step / 2; y < size.height; y += step) {
      final int row = (y / step).floor();
      for (double x = row.isOdd ? step / 2 : 0; x < size.width; x += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), q);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
