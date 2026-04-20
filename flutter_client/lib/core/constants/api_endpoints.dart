/// 与 `frontend/src/config/api.ts` 行为对齐，改为固定配置项管理。
///
/// Android 模拟器访问宿主机后端请使用 `10.0.2.2`；
/// 真机调试请改为局域网 IP；生产请改为网关域名。
class ApiEndpoints {
  ApiEndpoints._();

  /// 开发环境（Android Emulator）
  static const String httpBaseUrl = 'https://cyber-chat-api.dothings.one';
  static const String wsBaseUrl = 'ws://cyber-chat-api.dothings.one';

  static String get authBase => '$httpBaseUrl/api/auth';

  /// POST，Header: `Authorization: Bearer <token>`，无 body。
  static String get forgeIdentityUrl => '$httpBaseUrl/api/auth/forge-identity';
  static String get forgeIdentityPreviewUrl => '$httpBaseUrl/api/auth/forge-identity/preview';
  static String get forgeIdentitySaveUrl => '$httpBaseUrl/api/auth/forge-identity/save';

  static String get chatWsBase => '$wsBaseUrl/api/ws';

  static String announcementsUrl() => '$httpBaseUrl/api/announcements';

  static String chatHistoryUrl(String roomId, {int limit = 200}) {
    final encoded = Uri.encodeComponent(roomId);
    return '$httpBaseUrl/api/chat/history/$encoded?limit=$limit';
  }

  static String roomMembersUrl(String roomId) {
    final encoded = Uri.encodeComponent(roomId);
    return '$httpBaseUrl/api/ws/rooms/$encoded/members';
  }
}
