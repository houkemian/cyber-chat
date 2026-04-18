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
      home: const CyberShell(),
    );
  }
}
