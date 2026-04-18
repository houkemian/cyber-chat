import 'package:flutter/material.dart';

import 'pixel_grid_overlay.dart';

/// 对应 Web `.crt-container` + `.page` 背景与 `.fx-layer` 光斑（简化版）。
class CrtAtmosphere extends StatelessWidget {
  const CrtAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _BodyGradient(),
        const Positioned.fill(child: PixelGridOverlay(step: 4, line: 1)),
        const _FxLayer(),
        child,
      ],
    );
  }
}

class _BodyGradient extends StatelessWidget {
  const _BodyGradient();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF05050C),
            gradient: RadialGradient(
              center: Alignment(-0.9, -0.88),
              radius: 1.25,
              colors: <Color>[
                Color(0x5038BDF8),
                Color(0x1822D3EE),
                Color(0x04070710),
              ],
              stops: <double>[0.0, 0.35, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.92, 0.95),
              radius: 1.0,
              colors: <Color>[
                Color(0x35EC4899),
                Color(0x12A855F7),
                Color(0x00000000),
              ],
              stops: <double>[0.0, 0.4, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x0C00F0FF),
                Color(0x00000000),
                Color(0x08BC00FF),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FxLayer extends StatelessWidget {
  const _FxLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned(left: -24, top: 36, child: _spark(140, const Color(0xDD22D3EE))),
          Positioned(right: -36, top: 16, child: _spark(170, const Color(0xDDF472B6))),
          Positioned(left: 18, bottom: 120, child: _spark(90, const Color(0x99BC00FF))),
          Positioned(right: 32, bottom: 72, child: _spark(110, const Color(0xAA22D3EE))),
          const Positioned.fill(child: _ScanlineSweep()),
        ],
      ),
    );
  }

  static Widget _spark(double size, Color c) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.35),
        border: Border.all(color: c.withValues(alpha: 0.6), width: 1),
      ),
    );
  }
}

class _ScanlineSweep extends StatefulWidget {
  const _ScanlineSweep();

  @override
  State<_ScanlineSweep> createState() => _ScanlineSweepState();
}

class _ScanlineSweepState extends State<_ScanlineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return CustomPaint(
          painter: _ScanlinePainter(phase: t),
        );
      },
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0, -1 + phase * 2),
        end: Alignment(0, 1 + phase * 2),
        colors: const <Color>[
          Color(0x05FFFFFF),
          Color(0x08FFFFFF),
          Color(0x03FFFFFF),
          Color(0x05FFFFFF),
        ],
        stops: const <double>[0, 0.48, 0.52, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => oldDelegate.phase != phase;
}
