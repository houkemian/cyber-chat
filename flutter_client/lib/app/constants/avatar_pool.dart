/// 与 `frontend/src/App.tsx` `AVATAR_POOL` 对齐（Dicebear pixel-art）。
class AvatarPoolEntry {
  const AvatarPoolEntry({required this.seed, required this.label, required this.icon});

  /// `__NAME__` 表示使用当前 `cyber_name` 作为种子。
  final String seed;
  final String label;
  final String icon;
}

const List<AvatarPoolEntry> kAvatarPool = <AvatarPoolEntry>[
  AvatarPoolEntry(seed: '__NAME__', label: '身份像', icon: '👤'),
  AvatarPoolEntry(seed: 'mini-red-umbrella-2000', label: '小雨伞', icon: '☂️'),
  AvatarPoolEntry(seed: 'cactus-pixel-verde', label: '仙人掌', icon: '🌵'),
  AvatarPoolEntry(seed: 'retro-computer-9x-boot', label: '小电脑', icon: '💻'),
  AvatarPoolEntry(seed: 'floppy-disk-cyber-wave', label: '磁碟片', icon: '💾'),
  AvatarPoolEntry(seed: 'gameboy-neon-blink-99', label: '游戏机', icon: '🎮'),
  AvatarPoolEntry(seed: 'satellite-orbit-signal', label: '卫星锅', icon: '📡'),
  AvatarPoolEntry(seed: 'coffee-mug-terminal-hot', label: '咖啡杯', icon: '☕'),
  AvatarPoolEntry(seed: 'alien-capsule-static', label: '外星舱', icon: '🛸'),
  AvatarPoolEntry(seed: 'cassette-tape-rewind88', label: '磁带机', icon: '📼'),
  AvatarPoolEntry(seed: 'pixel-robot-unit-zero', label: '机器人', icon: '🤖'),
];

String dicebearPixelArtPngUrl(String seed, {int size = 128}) {
  final q = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/9.x/pixel-art/png?seed=$q&size=$size';
}
