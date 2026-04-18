class ChatRateLimit {
  ChatRateLimit._();

  /// 每位用户每秒最多发送消息条数（与 `frontend/src/config/chat.ts` 对齐）
  static const int maxSendsPerSecond = 2;

  /// 限流统计窗口（毫秒）
  static const int windowMs = 1000;
}
