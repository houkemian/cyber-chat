import 'package:shared_preferences/shared_preferences.dart';

/// 与 Web 端 `localStorage` / `sessionStorage` 键位对齐。
class SessionStore {
  SessionStore._();

  static const String keyCyberToken = 'cyber_token';
  static const String keyCyberName = 'cyber_name';
  static const String keyCfsUplinkIso = 'cfs_uplink_iso';
  static const String keyCyberAvatarIdx = 'cyber_avatar_idx';

  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCyberToken);
  }

  static Future<String?> readCyberName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCyberName);
  }

  /// 与 Web `AVATAR_STORAGE_KEY` 一致；未设置时返回 0。
  static Future<int> readCyberAvatarIdx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyCyberAvatarIdx) ?? 0;
  }

  static Future<void> saveSession({required String token, required String cyberName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCyberToken, token);
    await prefs.setString(keyCyberName, cyberName);
    // 仅在会话初次建立时写入接驳时间，后续刷新 token（如伪造身份）不重置。
    if (prefs.getString(keyCfsUplinkIso) == null) {
      await prefs.setString(keyCfsUplinkIso, DateTime.now().toUtc().toIso8601String());
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCyberToken);
    await prefs.remove(keyCyberName);
    await prefs.remove(keyCfsUplinkIso);
  }

  /// 持久化头像池下标，与 Web `AVATAR_STORAGE_KEY` 一致。
  static Future<void> saveCyberAvatarIdx(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyCyberAvatarIdx, idx);
  }

  static Future<void> ensureCfsUplinkStamp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(keyCfsUplinkIso) != null) return;
    await prefs.setString(keyCfsUplinkIso, DateTime.now().toUtc().toIso8601String());
  }

  static Future<String?> cfsUplinkStamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCfsUplinkIso);
  }
}
