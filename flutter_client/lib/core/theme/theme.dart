import 'package:flutter/material.dart';

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
    const baseText = TextStyle(
      fontFamily: 'Courier',
      color: CyberPalette.terminalGreen,
      letterSpacing: 0.35,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CyberPalette.pureBlack,
      colorScheme: const ColorScheme.dark(
        primary: CyberPalette.terminalGreen,
        secondary: CyberPalette.neonCyan,
        tertiary: CyberPalette.neonPurple,
        error: CyberPalette.danger,
        surface: CyberPalette.panelDark,
      ),
      textTheme: const TextTheme(
        headlineMedium: baseText,
        titleLarge: baseText,
        bodyLarge: baseText,
        bodyMedium: baseText,
        bodySmall: baseText,
        labelLarge: baseText,
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CyberPalette.frameDark,
          foregroundColor: CyberPalette.terminalGreen,
          textStyle: baseText.copyWith(fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: CyberPalette.terminalGreen, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
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
