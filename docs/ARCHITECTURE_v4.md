# ARCHITECTURE_v4.md
# 2000.exe · 系统架构快照 · Phase-3.5 记忆转储

> **文档定位**：在 Phase-3 基础上冻结 2026-04-01 最新提交（`33e766f`）的所有实现变更，重点覆盖命令面板重设计、雷达扫描成员动画、输入框通电闪烁三项交互升级，同时对全项目做一次完整的记忆转储，消除上下文衰减风险。  
> **撰写原则**：记录"为什么这么设计"与"关键数据流"，不默写大段代码。  
> **更新时间**：2026-04-01  
> **仓库**：https://github.com/houkemian/cyber-chat  
> **前序文档**：[ARCHITECTURE_v3.md](./ARCHITECTURE_v3.md)

---

## 0. 世界观 · 系统哲学（继承 v3）

> 这不是一个普通的聊天室。这是一个在千禧年末世数字荒野中燃烧的**赛博树洞**。  
> 每个接入的终端都是匿名的，每条消息都是一次短暂的数据残响——**1 分钟后自毁**。  
> 探测他人，是在黑暗中发射的一道雷达束。

Phase-3.5 核心变更（增量于 Phase-3）：

- **命令面板重排**：探测按钮压缩为正方形图标键，输入框占据面板 70%+ 宽度，传输按钮文字精简。
- **输入通电闪烁**：输入框获得焦点时，整个命令面板触发「绿电 → 青光 → 平息」600ms 单次动画，模拟老旧终端上电瞬间。
- **全屏雷达扫描**：探测按钮触发全屏蒙层，扫描线从屏幕底部向顶部扫过（2.2s），被扫中的成员名字依次从透明浮现，无成员时扫完后显示空态。

---

## 1. 技术栈总览（无新增依赖）

| 层级 | 技术 | 当前版本/状态 |
|------|------|------|
| 前端框架 | React 18 + TypeScript + Vite | `base: '/cyber-chat/'` |
| 前端路由 | React Router v6 `BrowserRouter` | `basename="/cyber-chat"` |
| 样式 | Tailwind CSS + 手写 `index.css`（~2900 行） | 像素赛博 Y2K 风格体系 |
| 容器化 | Docker Compose + nginx:alpine | 挂载自定义 `nginx.conf` |
| CI/CD | GitHub Actions SCP + SSH | Docker Compose 重启 |
| 实时通讯 | FastAPI WebSocket | 广播含 `online_count` |
| 头像服务 | DiceBear 9.x pixel-art API | 外部服务，无需后端改动 |

---

## 2. 项目目录结构（全量快照）

```
cyber_chat/
├── backend/
│   ├── api/
│   │   └── routes/
│   │       ├── auth.py          # POST /api/auth/send-key, /api/auth/verify
│   │       └── chat.py          # WS /api/ws/{room_id}, GET /api/chat/history/{room_id}
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
│   │   └── auth.py              # Pydantic 请求/响应体
│   ├── utils/
│   │   ├── generator.py         # cyber_name 生成器
│   │   ├── security.py          # JWT 签发/验证
│   │   ├── sms_mock.py          # 短信模拟（控制台打印）
│   │   └── ws_manager.py        # ConnectionManager 单例
│   ├── data/
│   │   └── cyber_chat.db        # SQLite 数据库文件
│   ├── Dockerfile
│   ├── main.py                  # FastAPI 入口 + 生命周期
│   ├── models.py                # ORM 模型
│   └── requirements.txt
├── frontend/
│   ├── public/
│   │   ├── favicon.svg
│   │   └── icons.svg
│   ├── src/
│   │   ├── components/
│   │   │   └── SignalGlitch.tsx  # 噪点故障动画装饰组件
│   │   ├── config/
│   │   │   └── api.ts           # HTTP_BASE_URL / CHAT_WS_BASE_URL
│   │   ├── pages/
│   │   │   ├── LoginTerminal.tsx # 登录终端 UI
│   │   │   └── RoomChat.tsx      # 核心聊天室（~760 行）
│   │   ├── App.tsx               # 全局状态 + Header + 路由
│   │   ├── index.css             # 全局 CSS（~2900 行，赛博风格体系）
│   │   └── main.tsx              # React 入口
│   ├── index.html                # viewport-fit=cover
│   ├── nginx.conf                # 单页 SPA + gzip 配置
│   ├── package.json
│   └── vite.config.ts            # base: '/cyber-chat/'
├── docs/
│   ├── ARCHITECTURE_v1.md
│   ├── ARCHITECTURE_v2.md
│   ├── ARCHITECTURE_v3.md
│   └── ARCHITECTURE_v4.md        # 本文档
├── .github/workflows/deploy.yml  # CI/CD
├── docker-compose.yml
└── .cursorrules                   # AI 协作规范
```

---

## 3. 后端架构（Phase-3.5，无变更）

### 3.1 FastAPI 入口（`backend/main.py`）

- 启动时调用 `db_manager.connect()` + `cache_manager.connect()`（当前：SQLite + 内存缓存）
- 关闭时调用 `ws_manager.close()`（清理 Redis 连接池）
- CORS：优先读取环境变量 `CORS_ORIGINS`；未设置时允许 localhost + 局域网段（`192.168.*`, `10.*`, `172.16-31.*`）

### 3.2 WebSocket 连接管理（`utils/ws_manager.py`）

```
ConnectionManager（单例 ws_manager）：
  rooms:     dict[room_id, list[WebSocket]]    ← 按房间隔离的在线连接池
  histories: dict[room_id, deque(maxlen=200)]  ← 内存历史（仅 chat 类型）
  _redis:    Optional[Redis]                    ← Redis 可选加速

关键方法：
  connect(ws, room)         → accept() + 登记到连接池
  disconnect(ws, room)      → 移出连接池，房间空时删除键
  broadcast_json(payload, room) → 向所有在线连接发送 JSON
                                   → 失败连接自动剔除（stale 清理）
                                   → chat 类型消息同步写入历史 deque
  get_room_history(room, limit) → 优先从 Redis 读；降级到内存 deque
  get_room_count(room)      → 返回当前房间在线数
```

### 3.3 WebSocket 路由（`api/routes/chat.py`）

```
WS /api/ws/{room_id}?token=<jwt>

鉴权：
  1) Query ?token=  2) Authorization: Bearer  3) X-Token header
  任一无效 → WS_1008_POLICY_VIOLATION 拒绝

接入流程：
  parse token → 提取 cyber_name
  ws_manager.connect(ws, room)
  broadcast system: "终端 <name> 已接入扇区 <room>"  ← 前端 join 正则匹配此格式
  loop:
    receive_text → content_moderation (当前直通)
    broadcast chat: {type, sender, content, timestamp}
    → 异步写库（失败不阻断广播）

断开流程：
  ws_manager.disconnect(ws, room)
  broadcast system: "终端 <name> 已断开扇区 <room>"   ← 前端 leave 正则匹配此格式
```

> **关键约束**：系统消息格式 `终端 (\S+) 已接入` / `终端 (\S+) 已断开` 与前端正则强耦合，修改需同步更新 `RoomChat.tsx` 中的 `systemKind` 识别逻辑。

### 3.4 身份认证（`api/routes/auth.py`）

```
POST /api/auth/send-key  → 生成 6 位验证码，打印到控制台（sms_mock），存入缓存
POST /api/auth/verify    → 校验验证码 → 签发 JWT（HS256, 24h）+ 生成 cyber_name
```

> **安全隐患（Phase-4 P0）**：存在万能验证码 `0000`，仅供开发调试；`JWT_SECRET` 默认值为 `dev-secret-change-me-in-prod`，生产必须通过环境变量覆盖。

---

## 4. 前端核心状态机（Phase-3.5 全量）

### 4.1 App.tsx 全局状态

| 状态 | 类型 | 用途 |
|------|------|------|
| `isLoggedIn` | `boolean` | 控制 Header 认证区渲染 |
| `cyberName` | `string \| null` | 展示当前身份密匙 |
| `showLogin` | `boolean` | 控制登录弹层 |
| `noisePhase` | `0-3` | 每 170ms 随机，驱动微动效 |
| `chatHeight` | `string` | `calc(100dvh - headerH - pad - gap)`，JS 精确计算 |
| `loginSeq` | `number` | 登录/退出时 +1，触发 RoomChat WS 重连/断开 |
| `avatarIdx` | `number` | 头像池当前索引，持久化至 `localStorage` |

**头像池（AVATAR_POOL，11 项）**：

```
0: { seed: '__NAME__' }  → 动态人像（使用 cyberName 为 DiceBear seed）
1-10: 固定物件 seed（雨伞/仙人掌/电脑/磁碟片/游戏机/卫星/咖啡杯/外星舱/磁带机/机器人）
```

**`chatHeight` 计算逻辑**：

```
header 实际高度（getBoundingClientRect）
+ container padding（移动端 16px * 2 = 32px, 桌面 32px）
+ gap（移动端 8px, 桌面 14px）
= reserved

chatHeight = calc(100dvh - ${reserved}px)   // 支持 dvh 时
           = calc(100vh  - ${reserved}px)   // 降级
```

### 4.2 RoomChat.tsx 状态机

```
channelState: 'switching' | 'online' | 'offline'

messages: ChatMessage[]
  ├── useMemo → systemMessages → SYS://FEED 区（上 15%）
  └── useMemo → userMessages   → USR://STREAM 区（flex:1）

memberList: string[]
  ├── 阶段一：syncHistoryThenConnect 时扫描历史 system 消息，顺序模拟 join/leave
  └── 阶段二：实时 WS onmessage 维护

inputFocused: boolean   ← 新增（Phase-3.5），控制通电闪烁
showMembers: boolean    ← 控制雷达扫描蒙层
```

**Refs**（均为 `useRef`，不触发重渲染）：

| Ref | 用途 |
|-----|------|
| `wsRef` | WebSocket 实例，房间切换时关闭重建 |
| `wsSeqRef` | 累计序号，防止旧闭包回调污染新 WS |
| `systemListRef` | 系统消息区 DOM，自动滚底 |
| `userListRef` | 用户消息区 DOM，自动滚底 |
| `switchNavTimerRef` | 切房动画定时器 |
| `historySyncTimerRef` | 历史流式渲染定时器 |
| `lifetimeTimerRef` | 消息生命周期扫描定时器（5s 间隔） |

### 4.3 ChatMessage 类型（完整）

```typescript
type SystemKind = 'join' | 'leave' | 'generic'

type ChatMessage = {
  id:           string       // nanoid 或 `sys-${Date.now()}`
  type:         'chat' | 'system'
  systemKind?:  SystemKind   // 实时 system 消息才有；历史 system 默认 generic
  sender?:      string
  content:      string
  timestamp:    string       // ISO 8601 UTC
  isHistory?:   boolean      // true → animate-pulse-once 入场
  expiresAt?:   number       // unix ms；仅实时 chat 消息，system/history 无
  dissolving?:  boolean      // true → msg-dissolve 像素散开动画
}
```

---

## 5. 命令面板重设计（Phase-3.5 核心）

### 5.1 布局策略

```
cmd-panel（flex, align-items: center, gap: 6px）：

  [cmd-scan-icon-btn 44×44px]  [cmd-input-wrap flex:1 min-w:0]  [cmd-exec-btn min-w:44px]
       ↑ 正方形图标                  ↑ 输入框占满剩余宽度             ↑ 精简文字
```

`cmd-input-wrap` 设 `flex: 1; min-width: 0`——在 flex 容器中，`min-width: 0` 防止内容撑开，确保输入框压缩到剩余空间（通常 > 70%）。

### 5.2 探测图标按钮（`cmd-scan-icon-btn`）

- SVG 内容：同心圆两个（半径 9 / 5）+ 旋转指针线 + 中心点
- 指针 `line` 带 CSS class `radar-sweep-hand`，`transform-origin: 12px 12px`，持续旋转（`sweep-rotate` 3s linear infinite）
- 按钮 `animation: scan-btn-idle` 2.8s 步进呼吸闪烁

### 5.3 输入框通电闪烁（`cmd-panel-powered`）

触发条件：`inputFocused === true`（`onFocus` / `onBlur` 切换）  
动画时序（600ms 单次 forwards）：

```
0%   → 无辉光，暗边框，黑色背景
8%   → 绿光爆闪：border-top 亮绿，上方散射 24px 绿色辉光，背景微绿
18%  → 绿光衰退
30%  → 青光接力：border-top 青色，上方散射 32px 青色辉光
50%  → 青光收敛
100% → 静默：极低亮度持续尾焰
```

设计意图：模拟老旧 CRT 终端「插电 → 电容充电 → 稳定」物理过程，赋予输入框获焦以仪式感。

---

## 6. 雷达扫描成员组件（`RadarScan`，Phase-3.5 核心）

### 6.1 组件生命周期

```
props: { roomName, memberList, onClose }

mount → phase: 'scanning'

useEffect([total]):
  为每个成员按"反序"（索引越大 = 在列表底部 = 先被扫到）计算 delay：
    delay_i = (total-1-i) / (total-1) * (SCAN_DURATION_MS * 0.85)
  → 在对应时间点 setVisibleCount(c => c + 1)
  → SCAN_DURATION_MS（2200ms）后 setPhase('revealed')

unmount → 清除所有 timer
```

### 6.2 扫描线视觉

```css
.radar-beam {
  position: absolute; bottom: 0; /* 初始在屏幕最底部 */
  animation: radar-beam-sweep 2.2s cubic-bezier(0.22, 0.6, 0.78, 0.94) forwards;
}

@keyframes radar-beam-sweep {
  0%   { bottom: 0;    }
  100% { bottom: 100%; }   /* 扫到屏幕顶部后消失 */
}

.radar-beam-line   → 2px 绿色发光线（绿色主线 + 两侧青色渐隐）
.radar-beam-glow   → 48px 向下余晖（绿→青渐变，opacity 渐出）
```

### 6.3 成员浮现逻辑

```
memberList = ['A', 'B', 'C', 'D']  (4人，0-3)

扫描线从下往上：
  先扫到底部成员 → revIdx = total-1-i
  A(i=0) revIdx=3 → 最后浮现（屏幕顶部）
  D(i=3) revIdx=0 → 最先浮现（屏幕底部）

每个 .radar-member-row 默认 opacity:0 transform:translateY(10px)
当 revIdx < visibleCount 时，添加 .radar-member-show → opacity:1, translateY(0)
过渡：400ms ease-out
```

### 6.4 层次结构

```
.radar-mask（全屏 fixed，z-index: 300）
  ├── .radar-aged       ← SVG fractalNoise 做旧噪点
  ├── .radar-bg-scanlines ← 横向扫描线纹理
  ├── .radar-vignette   ← 径向暗角
  ├── .radar-beam       ← 扫描线（仅 scanning 阶段，phase=revealed 时 unmount）
  ├── .radar-header     ← 顶部标题 + 关闭按钮（z-index: 10）
  ├── .radar-members    ← 成员列表（flex-direction: column, justify: flex-end）
  └── .radar-footer     ← 状态栏（扫描中/完毕）+ 关闭按钮
```

---

## 7. 布局全图（Phase-3.5，完整 ASCII）

```
┌─────────────────────────────────────────────────────┐
│  HEADER（headerRef 量高，shrink:0）                   │
│    [头像] 2000.exe [身份密匙] [扇区 Tab × 4] [登录/出]│
├─────────────────────────────────────────────────────┤
│  .chat-section（chatHeight = calc(100dvh - ...)）    │
│  ├─ BROADCAST://SIGNAL 公告区   flex: 0 0 15%        │
│  │    · 静态 ANNOUNCEMENTS 数组，6s 自动轮播          │
│  │    · 圆点手动切换                                  │
│  ├─ SYS://FEED 系统消息区       flex: 0 0 15%        │
│  │    · join(绿▶) / leave(红◀) / generic(琥珀◈)      │
│  │    · 自动滚底 (systemListRef)                      │
│  └─ USR://STREAM 用户消息区     flex: 1               │
│       · 行内排版：用户名[时间]内容                    │
│       · 奇偶行 cyan/fuchsia 双色                      │
│       · 消息到期 → dissolving → 像素散开 → 移除       │
│       · 历史/实时分界线（DATA ECHO · 数据残响）       │
│       · 自动滚底 (userListRef)                        │
├─────────────────────────────────────────────────────┤
│  历史同步进度条（isHistorySyncing 时显示）            │
├─────────────────────────────────────────────────────┤
│  CMD PANEL（shrink:0）                               │
│    [⊙ 44px]  > // __input (flex:1)__  [ 传输 TX ]   │
│      ↑                                    ↑          │
│    探测图标键                          精简传输键     │
│    (SVG 旋转指针)                                     │
├─────────────────────────────────────────────────────┤
│  切房遮罩（channelState=switching 时覆盖，z-index:20）│
│  信号中断特效（chaosFx 时覆盖，z-index:20）          │
└─────────────────────────────────────────────────────┘

全屏蒙层（z-index: 300，凌驾一切）：
  RadarScan 雷达扫描蒙层（showMembers=true 时）
```

---

## 8. CSS 关键动画体系（Phase-3.5 全量）

| 动画 class / keyframe | 触发时机 | 效果描述 |
|------|------|------|
| `msg-pixel-dissolve` | `msg.dissolving = true` | 8帧步进 750ms：blur+brightness渐增，clip-path从四角收缩，opacity→0 |
| `panel-power-on` | `inputFocused = true` | 600ms单次：绿电爆闪→青光散射→暗化平息，模拟终端上电 |
| `radar-beam-sweep` | RadarScan mount | 2.2s：扫描线从 bottom:0 动到 bottom:100%，cubic-bezier 加速收尾 |
| `sweep-rotate` | 探测按钮图标 | 3s linear infinite：SVG 指针线持续旋转 |
| `scan-btn-idle` | 探测按钮 | 2.8s steps(2) infinite：辉光呼吸 |
| `xmission-idle` | 传输按钮 | 2.2s steps(2) infinite：紫色辉光呼吸 |
| `history-pulse-once` | 历史消息入场 | 320ms ease-out 单次：亮度脉冲 |
| `header-dot-blink` | 在线指示点 | 1.6s steps(2) infinite：闪烁 |
| `ann-fade-in/out` | 公告轮播 | 300ms opacity 渐入/出 |
| `room-chaos-flicker` | 信号中断特效 | 随机闪烁遮罩 |

---

## 9. 移动端适配策略（Phase-3 + 3.5）

### 9.1 视口高度

```html
<!-- index.html -->
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
```

```css
html, body, #root, .page {
  height: 100dvh;   /* 动态视口高度，随地址栏收缩 */
  overflow: hidden;
}
```

### 9.2 安全区域（iPhone 刘海 / 底部手势条）

```css
.container {
  padding-top:    max(16px, env(safe-area-inset-top));
  padding-bottom: max(16px, env(safe-area-inset-bottom));
  padding-left:   max(16px, env(safe-area-inset-left));
  padding-right:  max(16px, env(safe-area-inset-right));
}
@media (max-width: 480px) {
  .container { padding: 8px; padding-top: max(8px, env(safe-area-inset-top)); ... }
}
```

### 9.3 Header 压缩断点

| 断点 | 变化 |
|------|------|
| `≤ 480px` | header padding 8px，title 20px，.tag 隐藏，头像 32px |
| `≤ 360px` | title 17px，头像 28px |

### 9.4 输入框移动端除魔

```css
.cmd-input {
  font-size: 16px;          /* 防 iOS 自动缩放（< 16px 会触发 zoom） */
  -webkit-appearance: none; /* 消除 iOS 默认输入框样式 */
  touch-action: manipulation; /* 禁用双击缩放 */
}
```

---

## 10. 数据流全图

```
用户行为                前端（RoomChat.tsx）              后端（FastAPI）
────────────           ─────────────────────           ────────────────
页面加载
  → useEffect([roomId, loginSeq])
  → GET /api/chat/history/{room_id}  ──────────────→  ws_manager.get_room_history()
  ← normalizedHistory                ←──────────────  返回最近 200 条 chat 消息
  → 扫描历史 system 消息重建 memberList
  → 流式渲染历史（20ms 间隔）
  → setMessages(normalizedHistory)
  → WS 连接 /api/ws/{room_id}?token= ──────────────→  ws_manager.connect(ws, room)
                                                       broadcast "已接入"
  ← {type:'system', content:'已接入'} ←──────────────
  → setChannelState('online')

用户发送消息
  → ws.send(text)                    ──────────────→  content_moderation
                                                       ws_manager.broadcast_json(chat)
                                                       db_manager.save_chat_message（异步，失败不阻断）
  ← {type:'chat', sender, content}   ←──────────────（包括发送者自己）
  → push to messages, set expiresAt = now + 60000ms

1分钟后
  → lifetimeTimerRef 每 5s 扫描
  → 找到 expiresAt <= now → dissolving: true
  → 800ms 后 filter 移除

用户点击探测
  → setShowMembers(true)
  → RadarScan mount
  → 扫描线动画 2.2s
  → 成员按延迟顺序浮现
  → phase = 'revealed'

用户退出登录
  → logout()
  → 清除 localStorage（token/name）
  → setLoginSeq(n+1)
  → useEffect 重跑，token 为空
  → ws.close()                       ──────────────→  ws_manager.disconnect
                                                       broadcast "已断开"
  → setChannelState('offline')
  → setMemberList([])
```

---

## 11. API 接口速查表（Phase-3.5，无新增）

| 方法 | 路径 | 认证 | 描述 |
|------|------|------|------|
| `POST` | `/api/auth/send-key` | 无 | 发送验证码（控制台打印） |
| `POST` | `/api/auth/verify` | 无 | 验证码核验 → JWT + cyber_name |
| `WS` | `/api/ws/{room_id}?token=` | JWT | 实时聊天（广播 online_count） |
| `GET` | `/api/chat/history/{room_id}?limit=200` | 无 | 拉取历史（最近 200 条 chat） |
| `GET` | `/health` | 无 | 心跳探针 |

---

## 12. 环境变量速查表

| 变量 | 默认值 | 生产必填 | 说明 |
|------|------|------|------|
| `JWT_SECRET` | `dev-secret-change-me-in-prod` | ✅ | JWT 签发密钥 |
| `CORS_ORIGINS` | `""` | ✅ | 允许跨域来源，逗号分隔 |
| `DATABASE_URL` | SQLite 本地文件 | 建议 | PostgreSQL DSN |
| `REDIS_URL` | `""` | 可选 | Redis DSN，未设置降级内存 |
| `VITE_HTTP_BASE_URL` | `""` | ✅ | 前端 HTTP API 根路径 |
| `VITE_WS_BASE_URL` | `""` | ✅ | 前端 WebSocket 根路径 |

---

## 13. 已落地完整清单

### ✅ Phase-1（见 ARCHITECTURE_v1.md）
- FastAPI WebSocket 多房间广播架构
- JWT 鉴权（HS256，24h）
- 四扇区预设（sector-001/404/777/999）
- 历史消息 HTTP 拉取 + 流式渲染动画
- 基础像素赛博 UI 风格建立

### ✅ Phase-2（见 ARCHITECTURE_v2.md）
- 子路径部署三层坐标对齐（Vite base + Router basename + nginx SPA fallback）
- 房间切换 React Router navigate，修复 basename 丢失
- 数据残响分界线（历史/实时消息可见边界）
- 在线人数后端真实统计（`online_count` 随广播下发）
- 登录后自动重连（`loginSeq` prop 触发 effect 重跑）
- 命令面板移动端除魔
- 像素赛博按钮 + 传送登录按钮（CRT 动效体系）
- GitHub Actions CI/CD

### ✅ Phase-3（见 ARCHITECTURE_v3.md）
- 消息 1 分钟生命周期 + 像素散开动画
- 三区布局（公告 15% / 系统 15% / 用户 flex:1）+ 公告轮播组件
- 头像池扩展（11 种，localStorage 持久化）
- 扇区成员探测（历史扫描初始化 + 实时 WS 维护 + 做旧蒙层）
- 系统消息三色分级（join 绿 / leave 红橙 / generic 琥珀黄）
- 消息行内排版（用户名+时间+内容 inline）
- 退出链路修复（loginSeq+1，WS 彻底关闭）
- 移动端 Header 两级断点压缩 + 100dvh + safe-area-inset

### ✅ Phase-3.5（本文档）
- **命令面板重排**：探测 → 44px 正方形 SVG 图标键（带指针旋转动画），输入框 flex:1 占主体，传输按钮文字精简
- **输入通电闪烁**：`cmd-panel-powered`，绿电→青光→平息，600ms 单次，`inputFocused` 状态驱动
- **全屏雷达扫描**：`RadarScan` 组件全屏覆盖，扫描线从底向顶 2.2s，成员按反序延迟浮现，做旧三层背景（噪点/扫描线纹理/暗角）

---

## 14. Phase-4 待建

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产安全加固 | 移除万能密码 `0000`，轮换 `JWT_SECRET`，CORS_ORIGINS 精确注入 |
| P0 | PostgreSQL 正式接入 | 完善 `db/postgres_provider.py`，执行 schema 迁移，替换内存存储 |
| P0 | 公告 API 化 | `GET /api/announcements`，后端管理员下发，替换前端静态数组 |
| P1 | 成员列表 API 化 | `GET /api/ws/rooms/{room_id}/members`，后端返回真实在线用户，彻底替代字符串解析方案 |
| P1 | WS 心跳保活 | 客户端 ping / 服务端 pong，防止长连接被 Nginx 60s 超时断开 |
| P1 | AI 气氛组 Agent | `/backend/services/ai_agent.py`，定时发送赛博风格语录，禁止污染主路由鉴权链路 |
| P1 | 内容安全拦截 | 填充 `content_moderation` 占位函数，接入关键词过滤或第三方风控 SDK |
| P2 | 历史消息分页 | `before_timestamp` / `cursor` 参数，支持向上翻页加载更早记录 |
| P2 | 消息去重 | 切房边界 WS 与历史重叠时，`timestamp+sender+content` 联合去重 |
| P2 | 消息生命周期服务端同步 | 后端在存储时附加 TTL，历史接口不返回已过期消息，前端 `expiresAt` 改为服务端下发 |
| P2 | PWA / 离线缓存 | Service Worker，添加到桌面体验 |

---

## 15. Git 提交历史（截至快照时间）

```
33e766f  feat: compact scan icon btn, input focus power-on flash, full-screen radar scan animation
6cac576  fix: mobile viewport - use 100dvh, compress container padding, safe-area-inset support
5855568  feat: Phase-3 - message TTL, 3-panel layout, member scan, system msg styling, logout fix, mobile header
2839546  fix: include frontend/nginx.conf in SCP deploy transfer
3f59acd  fix: SPA refresh 404, login auto-reconnect, teleport btn, mobile overflow
8713097  fix: deploy docker script
ffe40de  fix: deploy docker script
482cf4a  fix: sub-path deployment - router navigate and nginx SPA fallback
04deaaa  fix: add Dockerfile
0a5ac25  fix: upgrade deploy.yml
7607190  fix: upgrade deploy.yml
9bc0fa5  fix: upgrade node version to 20 for vite build
43c6e20  domain:dothings.one
554f6b6  docker
25d05aa  docker
221dcc1  feat: Y2K cyber UI - mobile adaptation and cmd panel redesign
8dea686  docs: add ARCHITECTURE_v1.md - Phase-1 system snapshot
859ccd7  feat: initial commit - 2000.exe Cyber Dream Space full-stack Y2K cyberpunk chat
```

---

*本文档生成于 Phase-3.5 开发完结节点（2026-04-01），commit `33e766f`，冻结当前架构共识。*  
*后续重大架构变更请同步更新本文件或新建 `ARCHITECTURE_v5.md`。*
