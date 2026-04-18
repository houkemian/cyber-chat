import 'package:flutter/material.dart';

class SectorPreset {
  const SectorPreset({required this.id, required this.name});

  final String id;
  final String name;
}

/// 与 `RoomChat.tsx` 扇区列表一致
const List<SectorPreset> kPresetSectors = <SectorPreset>[
  SectorPreset(id: 'sector-001', name: '午夜心碎俱乐部'),
  SectorPreset(id: 'sector-404', name: '赛博酒保'),
  SectorPreset(id: 'sector-777', name: '废弃数据中心'),
  SectorPreset(id: 'sector-999', name: '星空物语'),
];

enum RoomThemeKind { heartbreak, bartender, datacenter, starry }

RoomThemeKind roomThemeForId(String roomId) {
  switch (roomId) {
    case 'sector-001':
      return RoomThemeKind.heartbreak;
    case 'sector-404':
      return RoomThemeKind.bartender;
    case 'sector-777':
      return RoomThemeKind.datacenter;
    case 'sector-999':
      return RoomThemeKind.starry;
    default:
      return RoomThemeKind.starry;
  }
}

/// 与 `index.css` `:root` / `data-theme` token 对齐（用于 Flutter 装饰色）
class RoomThemeTokens {
  const RoomThemeTokens({
    required this.neonPrimary,
    required this.neonSecondary,
    required this.terminalAmber,
    required this.glowRadius,
  });

  final Color neonPrimary;
  final Color neonSecondary;
  final Color terminalAmber;
  final double glowRadius;

  static RoomThemeTokens forKind(RoomThemeKind kind) {
    switch (kind) {
      case RoomThemeKind.heartbreak:
        return const RoomThemeTokens(
          neonPrimary: Color(0xFFFF00FF),
          neonSecondary: Color(0xFF3B0A52),
          terminalAmber: Color(0xFFFF8FCF),
          glowRadius: 20,
        );
      case RoomThemeKind.bartender:
        return const RoomThemeTokens(
          neonPrimary: Color(0xFF00FFFF),
          neonSecondary: Color(0xFF05304A),
          terminalAmber: Color(0xFFFFC36E),
          glowRadius: 20,
        );
      case RoomThemeKind.datacenter:
        return const RoomThemeTokens(
          neonPrimary: Color(0xFFFFBF00),
          neonSecondary: Color(0xFF6A6F76),
          terminalAmber: Color(0xFFFFCF4D),
          glowRadius: 22,
        );
      case RoomThemeKind.starry:
        return const RoomThemeTokens(
          neonPrimary: Color(0xFFEAF4FF),
          neonSecondary: Color(0xFF7FB5FF),
          terminalAmber: Color(0xFFD8E8FF),
          glowRadius: 34,
        );
    }
  }
}
