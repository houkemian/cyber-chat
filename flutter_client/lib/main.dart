import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/cyber_chat_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF05050C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CyberChatApp());
}
