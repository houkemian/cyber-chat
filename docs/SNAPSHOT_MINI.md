# SNAPSHOT_MINI

> 摘自 `ARCHITECTURE_v4.md`：**§2 目录**、**§7 布局图**、**§11 接口**，作轻量快照。

---

## 2. 项目目录结构（全量快照 · 2026-04-21）

```
cyber_chat/
├── backend/
│   ├── api/
│   │   └── routes/
│   │       ├── auth.py          # POST /api/auth/send-key, /api/auth/verify
│   │       └── chat.py          # WS /api/ws/{room_id}；GET history；GET /api/ws/rooms/{room_id}/members
│   ├── cache/
│   │   ├── base.py              # 缓存抽象基类
│   │   ├── manager.py           # 按环境变量选择实现
│   │   ├── memory_provider.py   # 内存缓存（当前默认）
│   │   └── redis_provider.py    # Redis 实现（待接入）
│   ├── core/
│   │   └── settings.py          # AppSettings（从 env 读取）
│   ├── db/
│   │   ├── base.py              # 数据库抽象基类
│   │   ├── manager.py           # 按环境变量选择实现
│   │   ├── postgres_provider.py # PostgreSQL 实现（待接入）
│   │   └── sqlite_provider.py   # SQLite 实现（当前默认）
│   ├── schemas/
│   │   ├── auth.py              # Pydantic 请求/响应体
│   │   └── announcements.py
│   ├── services/
│   │   ├── ai_agent.py          # CyberPoet：20-30 分钟广播，支持速率限制
│   │   ├── llm_agent.py         # 分区人格 LLM Agent：reply/action + MemoryManager
│   │   └── announcements_cache.py
│   ├── scripts/
│   │   └── test_llm_agent_action.py  # action 分路广播模拟脚本
│   ├── utils/
│   │   ├── generator.py         # cyber_name 生成器
│   │   ├── security.py          # JWT 签发/验证
│   │   ├── sms_mock.py          # 短信模拟（控制台打印）
│   │   └── ws_manager.py        # ConnectionManager 单例
│   ├── data/
│   │   └── cyber_chat.db        # SQLite 数据库文件
│   ├── Dockerfile
│   ├── main.py                  # FastAPI 入口 + 生命周期
│   ├── models.py                # ORM 模型；Pydantic：RoomHistoryMessage、RoomMembersResponse
│   └── requirements.txt
├── frontend/
│   ├── public/
│   │   ├── favicon.svg
│   │   └── icons.svg
│   ├── src/
│   │   ├── components/
│   │   │   └── SignalGlitch.tsx  # 噪点故障动画装饰组件
│   │   ├── config/
│   │   │   ├── api.ts           # HTTP_BASE_URL / CHAT_WS_BASE_URL（本地端口以该文件为准）
│   │   │   └── chat.ts          # 每用户发送限流配置
│   │   ├── pages/
│   │   │   ├── LoginTerminal.tsx # 登录终端 UI
│   │   │   └── RoomChat.tsx      # 核心聊天室（主题系统、WS 重试、CFS、成员 API）
│   │   ├── App.tsx               # 全局状态 + Header + 路由；根外包 `.crt-container`
│   │   ├── index.css             # 全局 CSS（多主题变量 + CRT + 雷达 + CFS）
│   │   └── main.tsx              # React 入口
│   ├── index.html                # viewport-fit=cover
│   ├── nginx.conf                # 单页 SPA + gzip 配置
│   ├── package.json
│   └── vite.config.ts            # base: '/cyber-chat/'
├── flutter_client/
│   ├── lib/
│   │   ├── app/
│   │   │   └── widgets/          # CyberHeaderBar · PixelAvatarShell · PixButton …
│   │   ├── core/
│   │   │   ├── constants/        # api_endpoints.dart
│   │   │   ├── storage/          # session_store.dart
│   │   │   └── theme/            # CyberPalette · PixelStyle
│   │   ├── features/
│   │   │   ├── auth/             # AuthRepository · LoginModal
│   │   │   └── chat/             # RoomChatPage
│   │   └── widgets/              # UptimeMonitor · PingMonitor
│   └── pubspec.yaml
├── docs/
│   ├── ARCHITECTURE_v1.md … v4.md
│   ├── PROJECT_MAP.md · STYLE_GUIDE.md · LOGIC_FLOW.md · SNAPSHOT_MINI.md
│   └── CONFIGURATION.md
├── .github/workflows/deploy.yml  # CI/CD
├── docker-compose.yml
└── .cursorrules                   # AI 协作规范
```

---

## 7. 布局全图（Phase-4，ASCII）

```
┌─────────────────────────────────────────────────────┐
│  HEADER（headerRef 量高，shrink:0）                   │
│    [头像] 2000.exe [身份密匙] [扇区 Tab × 4] [登录/出]│
├─────────────────────────────────────────────────────┤
│  .chat-section（chatHeight = calc(100dvh - ...)）    │
│  ├─ BROADCAST://SIGNAL 公告区   flex: 0 0 12%        │
│  │    · API 公告 + fallback，6s 自动轮播              │
│  │    · 圆点手动切换                                  │
│  ├─ SYS://FEED 系统消息区       flex: 0 0 18%        │
│  │    · join(绿▶) / leave(红◀) / generic(琥珀◈)      │
│  │    · AI action（[系统]：...）分路显示               │
│  │    · 自动滚底 (systemListRef)                      │
│  └─ USR://STREAM 用户消息区     flex: 1               │
│       · 行内排版：用户名[时间]内容                    │
│       · 主题变量驱动的奇偶行配色                        │
│       · 本地消息列表最多保留最近 200 条（与历史上限一致）│
│       · 历史/实时分界线（DATA ECHO · 数据残响）       │
│       · 自动滚底 (userListRef)                        │
├─────────────────────────────────────────────────────┤
│  历史同步进度条（isHistorySyncing 时显示）            │
├─────────────────────────────────────────────────────┤
│  CMD PANEL（shrink:0）                               │
│    [⊙ 44px]  > // __input (flex:1)__  [ 传输 TX ]   │
│    · 每用户每秒最多 2 条（本地限流）                  │
│      ↑                                    ↑          │
│    探测图标键                          精简传输键     │
│    (SVG 旋转指针)                                     │
├─────────────────────────────────────────────────────┤
│  切房遮罩（channelState=switching 时覆盖，z-index:20）│
│  信号中断特效（chaosFx 时覆盖，z-index:20）          │
└─────────────────────────────────────────────────────┘
```

全屏蒙层：

- `RadarScan`（`.radar-mask`，z-index: 300）
- CRT 滤镜叠层（`.crt-container::before` / `::after`，z-index 约 349–351，`pointer-events: none`，叠在雷达之上）
- 登录弹层（`.login-modal-mask`，z-index 1200+，避免被雷达层遮挡）

**顶栏与聊天区横向对齐**：`.container` 定义 `--chat-panel-r-inset`；`.header` 的 `padding-right` 与之对齐，使头像右缘与下方三区公共右边界一致。`.header` 另含 `--header-h-scale` 压缩顶栏高度。

---

## 11. API 接口速查表（快照）

| 方法 | 路径 | 认证 | 描述 |
|------|------|------|------|
| `POST` | `/api/auth/send-key` | 无 | 发送验证码（控制台打印） |
| `POST` | `/api/auth/verify` | 无 | 验证码核验 → JWT + cyber_name |
| `POST` | `/api/auth/forge-identity/preview` | JWT | 生成预览新昵称；返回 `cyber_name` + `remaining_attempts`；上限 999 次 |
| `POST` | `/api/auth/forge-identity/save` | JWT | 保存选定昵称 → 刷新 JWT + 写 `user_profiles` |
| `WS` | `/api/ws/{room_id}?token=` | JWT | 实时聊天；广播 `online_count`（去重人数） |
| `GET` | `/api/ws/rooms/{room_id}/members` | 无 | 当前扇区在线成员 `cyber_name[]` + `online_count`（与连接池一致） |
| `GET` | `/api/chat/history/{room_id}?limit=200` | 无 | 拉取历史（最近 200 条 chat） |
| `GET` | `/api/announcements` | 无 | 公告列表 `{ items }`，数据来自应用缓存 |
| `GET` | `/health` | 无 | 心跳探针 |

> 说明：LLM Agent 当前通过 WS 主链路旁路触发（`chat.py` 内 `create_task`），未新增公开 HTTP API。
