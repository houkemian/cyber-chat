import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/storage/session_store.dart';
import '../../data/auth_repository.dart';

enum LoginPhase { boot, idle, countdown, decoding, success }

class LoginTerminalController extends ChangeNotifier {
  LoginTerminalController({
    AuthRepository? authRepository,
    this.onCompleted,
  }) : _auth = authRepository ?? AuthRepository();

  final AuthRepository _auth;
  final void Function(String cyberName)? onCompleted;

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
  Timer? _successTimer;

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
    final tel = phone.trim();
    if (tel.length < 6) {
      error = '>> ERROR: 终端号长度不足，信道拒绝建立';
      notifyListeners();
      return;
    }

    try {
      await _auth.sendKey(tel);
      phase = LoginPhase.countdown;
      countdown = 60;
      _startCountdown();
      notifyListeners();
    } on AuthRepositoryException {
      error = '>> ERROR: 信道被干扰，请稍后重试';
      phase = LoginPhase.idle;
      notifyListeners();
    }
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

    try {
      final result = await _auth.verify(
        phoneNumber: phone.trim(),
        smsCode: code.trim(),
      );
      await SessionStore.saveSession(token: result.token, cyberName: result.cyberName);
      cyberName = result.cyberName;
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      phase = LoginPhase.success;
      notifyListeners();
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(milliseconds: 2000), () {
        onCompleted?.call(cyberName);
      });
    } on AuthRepositoryException catch (e) {
      if (e.message == 'invalid_or_expired_code') {
        error = '>> ERROR: 验证矩阵拒绝握手 // 密匙失配或跃迁窗口已冻结';
      } else {
        error = '>> ERROR: 时空通道异常，请重试';
      }
      phase = LoginPhase.countdown;
      notifyListeners();
    }
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
    _successTimer?.cancel();
    _auth.dispose();
    super.dispose();
  }
}
