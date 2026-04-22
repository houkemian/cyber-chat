import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme/theme.dart';

class PingMonitor extends StatefulWidget {
  const PingMonitor({super.key});

  @override
  State<PingMonitor> createState() => _PingMonitorState();
}

class _PingMonitorState extends State<PingMonitor> {
  final Random _rng = Random();
  Timer? _timer;
  int _pingMs = 20;

  @override
  void initState() {
    super.initState();
    _refreshPing();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(_refreshPing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshPing() {
    _pingMs = 20 + _rng.nextInt(131); // 20..150
  }

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    List<Shadow>? shadows;

    if (_pingMs <= 60) {
      label = '[OK] LATENCY: ${_pingMs}ms';
      color = const Color(0xFF39FF14);
    } else if (_pingMs <= 100) {
      label = '[WARN] LATENCY: ${_pingMs}ms';
      color = const Color(0xFFFFD700);
    } else {
      label = '[ERR] LATENCY: ${_pingMs}ms';
      color = Colors.red;
      shadows = const <Shadow>[
        Shadow(
          color: Colors.red,
          blurRadius: 8,
        ),
      ];
    }

    return Text(
      label,
      style: TextStyle(
        fontFamily: CyberFonts.pixel,
        fontSize: 12,
        height: 1.2,
        color: color,
        shadows: shadows,
      ),
    );
  }
}
