export const CHAT_RATE_LIMIT = {
  /** 每位用户每秒最多发送消息条数 */
  maxSendsPerSecond: 2,
  /** 限流统计窗口（毫秒） */
  windowMs: 1000,
} as const

