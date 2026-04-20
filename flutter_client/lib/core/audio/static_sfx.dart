import 'package:audioplayers/audioplayers.dart';

/// 全局电流噪声 SFX（用于重构昵称/头像的短反馈音）。
class StaticSfx {
  StaticSfx._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _ready = false;

  static Future<void> _ensureReady() async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    _ready = true;
  }

  static void playElectricHum() {
    _playElectricHumInternal();
  }

  static Future<void> _playElectricHumInternal() async {
    try {
      await _ensureReady();
      await _player.stop();
      await _player.play(AssetSource('audio/electric_hum.wav'), volume: 0.75);
    } catch (_) {
      // 音效不可用时静默降级，不阻塞核心交互流程。
    }
  }
}
