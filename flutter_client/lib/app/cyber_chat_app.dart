import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'cyber_shell.dart';

class CyberChatApp extends StatelessWidget {
  const CyberChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2000.exe',
      debugShowCheckedModeBanner: false,
      theme: CyberTheme.darkTheme,
      themeMode: ThemeMode.dark,
      builder: (BuildContext context, Widget? child) {
        return DefaultTextStyle(
          style: const TextStyle(fontFamily: CyberFonts.pixel),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const CyberShell(),
    );
  }
}
