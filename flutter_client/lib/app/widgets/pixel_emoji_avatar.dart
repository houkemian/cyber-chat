import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/pixel_style.dart';

/// 低分辨率栅格化 Emoji 再放大，配合 [FilterQuality.none] 形成像素块效果。
///
/// 先将字符绘制到 [kEmojiRasterSize] 方形位图，再用 [RawImage] 拉伸到 [size]。
/// 过小会导致放大后糊成一片；48px 栅格在常见顶栏尺寸下仍保持明显像素格，但细节更清楚。
const int kEmojiRasterSize = 48;

/// 与 [kEmojiRasterSize] 匹配的单字 Emoji 字号（约占边长 ~0.81，居中留白）。
const double _kEmojiFontToEdge = 0.8125;

/// Emoji 像素化头像：默认可带 Win95 浮雕外框；嵌入 [PixelAvatarShell] 时设 [showFrame]: false。
class PixelatedEmojiAvatar extends StatefulWidget {
  const PixelatedEmojiAvatar({
    super.key,
    required this.emoji,
    this.size = 64,
    this.showFrame = true,
  });

  final String emoji;

  /// 内容区边长；[showFrame] 为 true 时总占位另加 4px（2px 立体边 ×2）。
  final double size;

  /// 为 false 时不画 Win95 壳，仅占满 [size]（供外层统一包边）。
  final bool showFrame;

  @override
  State<PixelatedEmojiAvatar> createState() => _PixelatedEmojiAvatarState();
}

class _PixelatedEmojiAvatarState extends State<PixelatedEmojiAvatar> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rasterize());
  }

  @override
  void didUpdateWidget(covariant PixelatedEmojiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emoji != widget.emoji) {
      _image?.dispose();
      _image = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rasterize());
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _rasterize() async {
    final ui.Image? next = await _renderEmojiToRaster(widget.emoji);
    if (!mounted) {
      next?.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = next;
    });
  }

  /// 在极小画布上绘制 Emoji，再 [toImage] 为位图供放大。
  static Future<ui.Image?> _renderEmojiToRaster(String emoji) async {
    final String g = emoji.trim();
    if (g.isEmpty) return null;
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final double w = kEmojiRasterSize.toDouble();
      final double h = kEmojiRasterSize.toDouble();
      final double fontSize = w * _kEmojiFontToEdge;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFFD4D4D4),
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: g,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.0,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      );
      tp.layout(maxWidth: w);
      tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(kEmojiRasterSize, kEmojiRasterSize);
      picture.dispose();
      return image;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size.clamp(8.0, 512.0);
    const double borderW = 2;
    final double inner = widget.showFrame ? (s - borderW * 2).clamp(1.0, s) : s;

    final Widget raster = SizedBox(
      width: inner,
      height: inner,
      child: _image == null
          ? const ColoredBox(color: Color(0xFF808080))
          : RawImage(
              image: _image,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              width: inner,
              height: inner,
            ),
    );

    if (!widget.showFrame) {
      return SizedBox(width: s, height: s, child: raster);
    }

    return SizedBox(
      width: s,
      height: s,
      child: Container(
        decoration: PixelStyle.win95Well(face: const Color(0xFFC0C0C0)),
        alignment: Alignment.center,
        child: raster,
      ),
    );
  }
}
