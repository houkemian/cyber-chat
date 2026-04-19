import 'dart:math';

/// 与 `frontend/src/App.tsx` `AVATAR_POOL` 概念对齐：首项为 DiceBear 身份像；其后为像素 Emoji，以及 **`2×N` 条即时随机种子的 `pixel-art`**（`N = kPixelEmojiPool.length`，会话内按槽位缓存种子）。
///
/// **重要**：带 [AvatarPoolEntry.pixelEmoji] 的条目由 [PixelatedEmojiAvatar] 绘制，不经 DiceBear。
class AvatarPoolEntry {
  const AvatarPoolEntry({
    required this.seed,
    required this.label,
    required this.icon,
    this.style = 'pixel-art',
    this.pixelEmoji,
  });

  /// `__NAME__` 表示使用当前 `cyber_name` 作为种子。
  final String seed;
  final String label;
  final String icon;

  /// DiceBear 9.x 风格 slug；仅当 [pixelEmoji] 为空时参与 URL。
  final String style;

  /// 非空时顶栏/壳内使用像素 Emoji，不请求 DiceBear。
  final String? pixelEmoji;
}

/// 像素物件 Emoji 池（经典科技、载具、赛博生物、Y2K、废土化学、面具、天文、命运、旧物等）。
///
/// [kAvatarPool]：`[0]` 身份像；`[1..N]` 像素 Emoji；`[N+1..N+2N]` 共 `2N` 条 **即时随机** `pixel-art`（原固定 pixel-art + bottts-neutral 槽位合并为此）。
const List<String> kPixelEmojiPool = <String>[
  // 💻 经典科技与黑客
  '💾', '💽', '💻', '🖥️', '🖨️', '🖱️', '📟', '📠', '📡', '🔋', '🔌', '💡', '🕹️', '🎮',
  // 🚀 载具与深空探索
  '🚀', '🛸', '🛰️', '🚁', '🛶', '🛵', '🏍️', '🏎️', '🚓', '🚑', '🚒', '🚜', '🛴', '🛹',
  // 👾 赛博生物与变异体
  '👾', '👽', '🤖', '👻', '💀', '☠️', '🧠', '👁️', '🦷', '🦠', '🦖', '🐙', '🕷️', '🦂',
  // 🦆 诡异/反差萌物件
  '🦆', '🦉', '🦇', '🦩', '🦚', '🦡', '🧊', '🧅', '🍄', '🌵', '🥀', '🔥', '🌪️', '⚡',
  // 💊 废土生存与化学物质
  '💊', '💉', '🩸', '🧪', '🧫', '🧬', '🔬', '🔭', '🧲', '⚙️', '💣', '🧨', '🔪', '🗡️',
  // 🎭 伪装与神秘面具
  '🎭', '👺', '👹', '🤡', '🎃', '🕶️', '🥽', '🥼', '🎩', '👑', '🎒', '🧳', '☂️', '🌂',
  // 🔮 能量、魔法与天文
  '🔮', '🧿', '🌀', '🪐', '☄️', '🌕', '🌒', '🌞', '🌜', '⭐', '🌟', '🌠', '🌌', '☁️',
  // 🎲 赌博与命运
  '🎲', '🎰', '🎳', '🎱', '🎯', '🃏', '🀄', '🎟️', '🎫', '🏆', '🏅', '🪙', '💎', '💰',
  // 📻 旧时代遗物
  '📻', '📺', '📼', '📷', '📸', '📹', '🎞️', '📞', '☎️',
];

final List<AvatarPoolEntry> kAvatarPool = <AvatarPoolEntry>[
  const AvatarPoolEntry(seed: '__NAME__', label: '身份像', icon: '👤', style: 'pixel-art'),
  for (int i = 0; i < kPixelEmojiPool.length; i++)
    AvatarPoolEntry(
      seed: 'px-e-$i',
      label: kPixelEmojiPool[i],
      icon: kPixelEmojiPool[i],
      style: 'pixel-art',
      pixelEmoji: kPixelEmojiPool[i],
    ),
  // 原 121 固定 pixel-art + 121 bottts-neutral → 合并为 2N 槽，DiceBear 种子见 [_runtimePixelArtDicebearSeed]。
  for (int i = 0; i < kPixelEmojiPool.length * 2; i++)
    AvatarPoolEntry(
      seed: '__RT_RND__$i',
      label: '随机像·${i + 1}',
      icon: '🎲',
      style: 'pixel-art',
    ),
];

/// 每个 `__RT_RND__*` 槽位在进程内首次请求时生成随机串，之后稳定（换槽位即新随机）。
final Map<String, String> _runtimeRandomPixelArtSeeds = <String, String>{};

String _runtimePixelArtDicebearSeed(String entrySeed) {
  return _runtimeRandomPixelArtSeeds.putIfAbsent(entrySeed, () {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random r = Random.secure();
    return List<String>.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  });
}

/// 构建 DiceBear PNG URL；[style] 须与官方 slug 一致（如 `pixel-art`）。
String dicebearAvatarPngUrl(String seed, {required String style, int size = 128}) {
  final String q = Uri.encodeComponent(seed);
  return 'https://api.dicebear.com/9.x/$style/png?seed=$q&size=$size';
}

/// 聊天行等「仅昵称字符串」场景：仍用人像像素风。
String dicebearPixelArtPngUrl(String seed, {int size = 128}) {
  return dicebearAvatarPngUrl(seed, style: 'pixel-art', size: size);
}

/// 根据池条目与当前赛博名解析种子与风格（顶栏 / 身份重构用）。
/// 若条目为 [pixelEmoji] 头像则返回 `null`，由 UI 走 [PixelatedEmojiAvatar]。
String? dicebearUrlForPoolEntry(AvatarPoolEntry entry, String? cyberName, {int size = 128}) {
  if (entry.pixelEmoji != null && entry.pixelEmoji!.trim().isNotEmpty) {
    return null;
  }
  final String seed;
  if (entry.seed == '__NAME__') {
    seed = cyberName?.trim().isNotEmpty == true ? cyberName! : 'midnight';
  } else if (entry.seed.startsWith('__RT_RND__')) {
    seed = _runtimePixelArtDicebearSeed(entry.seed);
  } else {
    seed = entry.seed;
  }
  // 历史上若误用 `shapes` 会得到几何抽象图；统一改为人像 pixel-art。
  final String style = entry.style == 'shapes' ? 'pixel-art' : entry.style;
  return dicebearAvatarPngUrl(seed, style: style, size: size);
}
