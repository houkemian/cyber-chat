import 'dart:async';

import 'package:flutter/material.dart';

import '../core/storage/session_store.dart';
import '../core/theme/pixel_style.dart';

class UptimeMonitor extends StatefulWidget {
  const UptimeMonitor({super.key});

  @override
  State<UptimeMonitor> createState() => _UptimeMonitorState();
}

class _UptimeMonitorState extends State<UptimeMonitor> {
  DateTime? _uplinkStartUtc;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bootstrapUplinkStart();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _bootstrapUplinkStart() async {
    String? iso = await SessionStore.cfsUplinkStamp();
    if (iso == null || iso.trim().isEmpty) {
      await SessionStore.ensureCfsUplinkStamp();
      iso = await SessionStore.cfsUplinkStamp();
    }
    DateTime? parsedUtc;
    if (iso != null && iso.trim().isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(iso.trim());
      if (parsed != null) {
        parsedUtc = parsed.toUtc();
      }
    }
    if (!mounted) return;
    setState(() {
      _uplinkStartUtc = parsedUtc ?? DateTime.now().toUtc();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final String h = d.inHours.toString().padLeft(2, '0');
    final String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return 'UPLINK $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now().toUtc();
    final DateTime start = _uplinkStartUtc ?? now;
    final Duration uptime = now.isAfter(start) ? now.difference(start) : Duration.zero;
    return Text(
      _formatDuration(uptime),
      style: PixelStyle.vt323(
        fontSize: 12,
        color: const Color(0xFFE0F2FE),
        height: 1.2,
      ),
    );
  }
}
