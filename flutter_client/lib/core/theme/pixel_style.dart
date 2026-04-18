import 'package:flutter/material.dart';

import 'theme.dart';

/// 与 `.cursorrules` 对齐：直角、硬边霓虹、核心色。
class PixelStyle {
  PixelStyle._();

  static TextStyle vt323({
    double fontSize = 14,
    Color? color,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: CyberFonts.pixel,
      fontSize: fontSize.roundToDouble(),
      color: color ?? CyberPalette.terminalGreen,
      fontWeight: fontWeight ?? FontWeight.w400,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  /// 硬边霓虹字（blur=0，仅位移色）。
  static List<Shadow> neonGlow(Color c) {
    return <Shadow>[
      Shadow(color: c, blurRadius: 0, offset: const Offset(1, 0)),
      Shadow(color: c.withValues(alpha: 0.7), blurRadius: 0, offset: const Offset(-1, 0)),
      Shadow(color: c.withValues(alpha: 0.5), blurRadius: 0, offset: const Offset(0, 1)),
    ];
  }

  /// Windows 95 浮雕（规约片段）。
  static BoxDecoration win95Well({required Color face}) {
    return BoxDecoration(
      color: face,
      border: const Border(
        top: BorderSide(color: Colors.white, width: 2),
        left: BorderSide(color: Colors.white, width: 2),
        bottom: BorderSide(color: Color(0xFF424242), width: 2),
        right: BorderSide(color: Color(0xFF424242), width: 2),
      ),
    );
  }
}
