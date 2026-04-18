import 'dart:io';
import 'dart:ui' as ui;

import '../../../core/storage/session_store.dart';

bool isCfsSlashCommand(String text) {
  final c = text.trim().toLowerCase();
  return c == '/whoami' || c == '/ls' || c == '/clear';
}

/// 与 `RoomChat.tsx` `buildCfsWhoami` 对齐（移动端可用字段）
Future<String> buildCfsWhoami({
  required String cyberName,
  required String roomId,
  required String roomName,
}) async {
  await SessionStore.ensureCfsUplinkStamp();
  final uplink = await SessionStore.cfsUplinkStamp() ?? DateTime.now().toUtc().toIso8601String();

  final tz = DateTime.now().timeZoneName;
  final lang = Platform.localeName;
  final views = ui.PlatformDispatcher.instance.views;
  final view = views.isEmpty ? null : views.first;
  final scr = view == null
      ? 'unknown×unknown'
      : '${view.physicalSize.width.toInt()}×${view.physicalSize.height.toInt()}';
  final dpr = view?.devicePixelRatio ?? 1.0;
  final tokenOk = (await SessionStore.readToken()) != null;

  const art = '''
 ██████╗██╗   ██╗██████╗ ███████╗██████╗ 
██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗
██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝
██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗
╚██████╗   ██║   ██████╔╝███████╗██║  ██║
 ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝''';

  final t0 = DateTime.tryParse(uplink);
  final t0s = t0 == null
      ? uplink
      : '${t0.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19)}Z';

  final lines = <String>[
    art,
    '',
    '  ── NODE_DESCRIPTOR :: $cyberName ──',
    '  UPLINK_KEY .... $cyberName',
    '  SESSION_T0 .... $t0s',
    '  SECTOR_ID ..... $roomId ($roomName)',
    '  GEO_BIND ...... TZ=$tz · LANG=$lang',
    '  CLIENT_SIG .... ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    '  VIEWPORT ...... $scr @${dpr}x',
    '  TOKEN_STATE ... ${tokenOk ? 'ARMED' : 'NULL'}',
  ];

  return lines.join('\n');
}

String buildCfsLs({
  required String roomName,
  required List<String> members,
  required List<({String id, String content})> announcements,
}) {
  final ann = <String>[];
  for (var i = 0; i < announcements.length; i += 1) {
    final a = announcements[i].content;
    final short = a.length > 48 ? '${a.substring(0, 48)}…' : a;
    ann.add('  │   ann_${(i + 1).toString().padLeft(2, '0')}.dat  $short');
  }
  final mem = members.isEmpty
      ? <String>['      └── (empty cluster — no peer handshakes)']
      : members.map((m) => '      └── NODE_ACTIVE :: $m').toList();

  return <String>[
    '  ./sector_assets/',
    '  ├── BROADCAST_HEAP/',
    ...ann,
    '  └── ONLINE_CLUSTER/',
    ...mem,
  ].join('\n');
}
