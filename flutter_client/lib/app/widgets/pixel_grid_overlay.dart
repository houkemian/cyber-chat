import 'package:flutter/material.dart';

/// 低对比度像素网格，增强 CRT / 千禧像素感（不拦截点击）。
class PixelGridOverlay extends StatelessWidget {
  const PixelGridOverlay({super.key, this.step = 4, this.line = 0.06});

  final double step;
  /// 线粗（逻辑像素），保持 ≥1 更易看出「像素块」边界。
  final double line;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          return CustomPaint(
            size: Size(c.maxWidth, c.maxHeight),
            painter: _PixelGridPainter(step: step, line: line),
          );
        },
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  _PixelGridPainter({required this.step, required this.line});

  final double step;
  final double line;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = line
      ..isAntiAlias = false;

    var x = 0.0;
    while (x <= size.width + step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      x += step;
    }
    var y = 0.0;
    while (y <= size.height + step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      y += step;
    }
  }

  @override
  bool shouldRepaint(covariant _PixelGridPainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.line != line;
}
