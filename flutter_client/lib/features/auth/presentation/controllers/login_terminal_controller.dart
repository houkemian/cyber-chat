import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum LoginPhase { boot, idle, countdown, decoding, success }

class LoginTerminalController extends ChangeNotifier {
  LoginPhase phase = LoginPhase.boot;
  String bootText = '';
  String phone = '';
  String code = '';
  int countdown = 0;
  String cyberName = '';
  String error = '';
  List<String> decodingLines = <String>[];

  Timer? _bootTimer;
  Timer? _countdownTimer;

  void startBoot() {
    const target = '[ SYSTEM BOOT... 2000.exe ]';
    var index = 0;
    _bootTimer?.cancel();
    _bootTimer = Timer.periodic(const Duration(milliseconds: 48), (timer) {
      index += 1;
      bootText = target.substring(0, index.clamp(0, target.length));
      notifyListeners();
      if (index >= target.length) {
        timer.cancel();
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          phase = LoginPhase.idle;
          notifyListeners();
        });
      }
    });
  }

  void onPhoneChanged(String value) {
    phone = value;
    notifyListeners();
  }

  void onCodeChanged(String value) {
    code = value.replaceAll(RegExp(r'\D'), '');
    notifyListeners();
  }

  Future<void> requestKey() async {
    error = '';
    if (phone.trim().length < 6) {
      error = '>> ERROR: 终端号长度不足，信道拒绝建立';
      notifyListeners();
      return;
    }

    phase = LoginPhase.countdown;
    countdown = 60;
    _startCountdown();
    notifyListeners();
  }

  Future<void> verify() async {
    error = '';
    if (code.trim().isEmpty) {
      error = '>> ERROR: 跃迁密匙为空，终端拒绝接入';
      notifyListeners();
      return;
    }

    phase = LoginPhase.decoding;
    decodingLines = _makeDecodingLines();
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    cyberName = 'ANON_${Random().nextInt(9999).toString().padLeft(4, '0')}';
    phase = LoginPhase.success;
    notifyListeners();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown <= 1) {
        countdown = 0;
        timer.cancel();
      } else {
        countdown -= 1;
      }
      notifyListeners();
    });
  }

  List<String> _makeDecodingLines() {
    const phrases = <String>[
      '>> INIT QUANTUM HANDSHAKE ...',
      '>> SYNC TIME-LAYER OFFSETS ...',
      '>> DECRYPT LEGACY CREDENTIALS ...',
      '>> CRC CHECK: PASS',
      '>> OPEN CHANNEL /CYBER/DREAM/SPACE',
      '>> OVERRIDE IDENTITY BOUNDARY ...',
      '>> LOAD MILLENNIUM PROFILE ...',
      '>> HANDSHAKE COMPLETE. ACCESS GRANTED.',
    ];

    final random = Random();
    return List<String>.generate(40, (i) {
      final buffer = StringBuffer();
      for (var j = 0; j < 12; j += 1) {
        buffer.write(random.nextInt(16).toRadixString(16).toUpperCase());
      }
      final prefix = i < phrases.length ? phrases[i] : '>> STREAM //';
      return '$prefix  0x$buffer';
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
