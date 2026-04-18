import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// 直角外壳：错位纯色「影」+ 霓虹描边，无柔和 blur。
class NeonY2kShell extends StatelessWidget {
  const NeonY2kShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: Transform.translate(
            offset: const Offset(4, 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CyberPalette.neonPurple.withValues(alpha: 0.35),
                border: Border.all(color: CyberPalette.neonCyan.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.9, -1),
                end: Alignment(1.1, 1.2),
                colors: <Color>[
                  Color(0xFF181028),
                  Color(0xFF0C0614),
                  Color(0xFF10081C),
                  Color(0xFF1A0C2A),
                ],
                stops: <double>[0.0, 0.32, 0.62, 1.0],
              ),
              border: Border(
                top: BorderSide(color: CyberPalette.neonCyan, width: 1),
                left: BorderSide(color: CyberPalette.neonCyan, width: 1),
                bottom: BorderSide(color: CyberPalette.neonPurple, width: 1),
                right: BorderSide(color: CyberPalette.neonPurple, width: 1),
              ),
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.85, -0.9),
                          radius: 1.1,
                          colors: <Color>[
                            const Color(0x38F472B6),
                            const Color(0x12A855F7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              CyberPalette.neonCyan.withValues(alpha: 0.85),
                              CyberPalette.neonPurple.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: child),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
