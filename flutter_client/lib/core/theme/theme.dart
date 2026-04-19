import 'package:flutter/material.dart';

/// `pubspec.yaml` → `assets/fonts/fz_pixel_12.ttf`（方正像素12）
class CyberFonts {
  CyberFonts._();

  static const String pixel = 'PixelFont';
}

class CyberPalette {
  CyberPalette._();

  static const Color pureBlack = Color(0xFF000000);
  static const Color terminalGreen = Color(0xFF39FF14);
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonPurple = Color(0xFFBC00FF);
  static const Color frameDark = Color(0xFF060B06);
  static const Color panelDark = Color(0xFF081108);
  static const Color danger = Color(0xFFF87171);
}

class CyberTheme {
  CyberTheme._();

  static ThemeData get darkTheme {
    final TextStyle baseText = TextStyle(
      fontFamily: CyberFonts.pixel,
      fontSize: 15,
      color: CyberPalette.terminalGreen,
      letterSpacing: 0.2,
    );
    final TextTheme scaled = ThemeData(brightness: Brightness.dark).textTheme.copyWith(
      headlineMedium: const TextStyle(fontSize: 22),
      titleLarge: const TextStyle(fontSize: 18),
      bodyLarge: const TextStyle(fontSize: 15),
      bodyMedium: const TextStyle(fontSize: 14),
      bodySmall: const TextStyle(fontSize: 12),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CyberPalette.pureBlack,
      fontFamily: CyberFonts.pixel,
      colorScheme: const ColorScheme.dark(
        primary: CyberPalette.terminalGreen,
        secondary: CyberPalette.neonCyan,
        tertiary: CyberPalette.neonPurple,
        error: CyberPalette.danger,
        surface: CyberPalette.panelDark,
      ),
      textTheme: scaled.apply(
        fontFamily: CyberFonts.pixel,
        bodyColor: CyberPalette.terminalGreen,
        displayColor: CyberPalette.terminalGreen,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberPalette.frameDark,
        hintStyle: baseText.copyWith(color: CyberPalette.terminalGreen.withValues(alpha: 0.35)),
        border: _inputBorder(CyberPalette.terminalGreen.withValues(alpha: 0.55)),
        enabledBorder: _inputBorder(CyberPalette.terminalGreen.withValues(alpha: 0.55)),
        focusedBorder: _inputBorder(CyberPalette.neonCyan),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: baseText.copyWith(fontSize: 14),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: baseText.copyWith(fontSize: 12, color: const Color(0xFFE0F2FE)),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: color, width: 1),
    );
  }
}
