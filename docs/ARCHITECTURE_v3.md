# ARCHITECTURE_v3.md
# 2000.exe · 系统架构快照 · Phase-3 记忆转储

> **文档定位**：在 Phase-2 基础上冻结本阶段所有实现变更，覆盖消息生命周期、头像池扩展、三区布局、成员探测、系统消息视觉分级、移动端压缩、退出链路修复等设计决策。  
> **撰写原则**：记录"为什么这么设计"与"关键数据流"，不默写大段代码。  
> **更新时间**：2026-04-01  
> **仓库**：https://github.com/houkemian/cyber-chat  
> **前序文档**：[ARCHITECTURE_v2.md](./ARCHITECTURE_v2.md)

---

## 0. 世界观 · 系统哲学（继承 v2，补充变更）

> 这不是一个普通的聊天室。这是一个在千禧年末世数字荒野中燃烧的**赛博树洞**。  
> 每个接入的终端都是匿名的，每条消息都是一次短暂的数据残响——**1 分钟后自毁**。

Phase-3 核心新增：

- **消息自毁**：所有实时聊天消息附带生命周期计时器，到期触发像素散开动画后销毁。
- **三区布局**：聊天主体新增公告区（15%），三区占比 15 / 15 / 65，输入区固定。
- **成员探测**：命令面板新增探测按钮，弹出带做旧效果的扇区成员蒙层。
- **系统消息分级**：进入/离开/通用三类系统消息颜色与图标差异化。
- **头像池扩展**：11 种头像可循环切换，持久化到 localStorage。
- **退出链路修复**：退出同步触发 WS 关闭与 offline 状态，消除残留发送窗口。

---

## 1. 技术栈总览（Phase-3 无新增依赖）

| 层级 | 技术 | 当前版本/状态 |
|------|------|------|
| 前端框架 | React 18 + TypeScript + Vite | `base: '/cyber-chat/'` |
| 前端路由 | React Router v6 `BrowserRouter` | `basename="/cyber-chat"` |
| 样式 | Tailwind CSS + 手写 `index.css`（2600+ 行） | 像素赛博 Y2K 风格体系 |
| 容器化 | Docker Compose + nginx:alpine | 挂载自定义 `nginx.conf` |
| CI/CD | GitHub Actions SCP + SSH | Docker Compose 重启 |
| 实时通讯 | FastAPI WebSocket | 广播含 `online_count` |
| 头像服务 | DiceBear 9.x pixel-art API | 外部服务，无需后端改动 |

完整技术栈见 ARCHITECTURE_v1.md §1。

---

## 2. 消息生命周期（Phase-3 核心新增）

### 2.1 设计目标

每条实时消息都是「短暂的数据残响」，到期后以像素化视觉散开，强化赛博短暂性世界观，同时控制聊天区内容密度。

### 2.2 实现机制

```
配置常量（RoomChat.tsx 顶部）：
  MESSAGE_LIFETIME_MINUTES = 1   // 分钟，可直接修改

接收实时消息时：
  expiresAt = Date.now() + MESSAGE_LIFETIME_MINUTES * 60 * 1000
  （仅 type: 'chat' 消息附加，system 消息和历史消息无过期）

扫描定时器（全局 lifetimeTimerRef，每 5s 触发）：
  遍历 messages，找到 expiresAt <= now && !dissolving 的消息
  → 标记 dissolving: true  （触发 CSS 像素散开动画）
  → setTimeout 800ms 后从 state 彻底 filter 移除
```

### 2.3 像素散开动画（`msg-dissolve`）

```css
/* 8 帧步进，750ms 总时长 */
@keyframes msg-pixel-dissolve {
  /* blur + brightness 渐增，drop-shadow 色差分离（青/粉/绿通道），
     clip-path 从四角向中心收缩，opacity 降至 0 */
}
```

关键设计：`clip-path: inset()` 模拟像素从边缘向内侵蚀；`drop-shadow` 多通道偏移模拟 CRT 色差，赋予散开的「赛博像素化」质感。

---

## 3. 布局重构（Phase-3）

### 3.1 三区 + 输入区纵向分割

```
┌─────────────────────────────────────────┐
│  Tab 栏（扇区切换，横向滚动）  shrink:0   │
├─────────────────────────────────────────┤
│  BROADCAST://SIGNAL 公告区   flex: 0 0 15%│
│    - 静态公告数组 ANNOUNCEMENTS           │
│    - 每 6s 自动轮播 + 圆点手动切换        │
├─────────────────────────────────────────┤
│  SYS://FEED 系统消息区       flex: 0 0 15%│
│    - 进入/离开/通用三色区分               │
├─────────────────────────────────────────┤
│  USR://STREAM 用户消息区      flex: 1     │
│    - 行内排版（用户名 + 时间 + 内容同行）  │
│    - 消息到期像素散开                     │
│    - 数据残响分界线（历史/实时边界）       │
├─────────────────────────────────────────┤
│  CMD PANEL 命令面板          shrink: 0    │
│    [探测 SCAN] > // _____________ [执行传输]│
└─────────────────────────────────────────┘
```

> **为什么用 `flex: 0 0 15%` 而非固定 px？**  
> 聊天区总高度由 JS 动态计算（`calc(100vh - headerH - 46px)`），绝对 px 在不同机型上会失控；百分比相对父容器保持三区比例稳定。

### 3.2 消息行内排版

旧方案：用户名 + 时间戳占一行，消息内容独占下一行，两行结构导致视觉拥挤。

新方案：`用户名 [时间] 消息内容` 三段 inline，超长自动换行（`word-break: break-all`），配合 `padding: 6px 6px 7px` 撑开行高：

```
.msg-sender    → 12px 加粗，奇偶行青/紫双色
.msg-time-inline → 11px 低调灰色
.msg-content-inline → 13px 白色正常权重
```

---

## 4. 扇区成员探测（Phase-3）

### 4.1 成员列表构建策略

无专用 API，通过两阶段从现有数据源重建：

```
阶段一：历史快照扫描（syncHistoryThenConnect 内）
  遍历 normalizedHistory 中 type === 'system' 的条目
  顺序模拟 join/leave：
    /终端\s+(\S+)\s+已接入/ → push 到 seedMembers（去重）
    /终端\s+(\S+)\s+已断开/ → splice 移除
  → setMemberList(seedMembers)   // 建立进房时初始快照

阶段二：实时 WS 追踪
  ws.onmessage 中同步维护 memberList：
    join  → 加入（去重）
    leave → 移除
```

**局限**：历史消息仅保留最近 200 条，200 条之前的进出事件无法追溯，可能漏算极早期加入的成员。Phase-4 建议增加后端 `/rooms/{id}/members` 接口彻底解决。

### 4.2 探测蒙层做旧效果

```
.members-overlay-box
  └── .members-aged-layer    ← SVG fractalNoise 颗粒纹理，mix-blend-mode: overlay
  └── .members-scanlines     ← 横向扫描线，0px/1px/3px 循环，opacity 14%
  └── .members-vignette      ← 径向渐变暗角，向边缘黑化 45%
  └── 内容层（z-index: 1）
```

三层叠加产生旧 CRT 监控屏幕质感。

---

## 5. 系统消息视觉分级（Phase-3）

新增 `SystemKind = 'join' | 'leave' | 'generic'` 类型标记，在 WS 收到消息时通过正则识别：

| 类型 | 识别规则 | 前缀图标 | 颜色 |
|------|------|------|------|
| `join` | `/已接入/` | `▶`（绿光） | `rgba(134,239,172,0.92)` 绿色系 |
| `leave` | `/已断开/` | `◀`（红光） | `rgba(252,165,165,0.85)` 红橙系 |
| `generic` | 其他 | `◈` | 琥珀黄（原色，不变） |

历史消息中的 system 条目 `systemKind` 为 `undefined`，默认渲染为 `sys-generic`。

---

## 6. 头像池（Phase-3）

### 6.1 AVATAR_POOL 定义（App.tsx）

```typescript
const AVATAR_POOL = [
  { seed: '__NAME__',                 label: '身份像', icon: '👤' }, // 动态人像
  { seed: 'mini-red-umbrella-2000',   label: '小雨伞', icon: '☂️' },
  { seed: 'cactus-pixel-verde',       label: '仙人掌', icon: '🌵' },
  { seed: 'retro-computer-9x-boot',   label: '小电脑', icon: '💻' },
  { seed: 'floppy-disk-cyber-wave',   label: '磁碟片', icon: '💾' },
  { seed: 'gameboy-neon-blink-99',    label: '游戏机', icon: '🎮' },
  { seed: 'satellite-orbit-signal',   label: '卫星锅', icon: '📡' },
  { seed: 'coffee-mug-terminal-hot',  label: '咖啡杯', icon: '☕' },
  { seed: 'alien-capsule-static',     label: '外星舱', icon: '🛸' },
  { seed: 'cassette-tape-rewind88',   label: '磁带机', icon: '📼' },
  { seed: 'pixel-robot-unit-zero',    label: '机器人', icon: '🤖' },
]
```

- `seed === '__NAME__'` 时用 `cyberName`（或 `'midnight'` 兜底）作为动态种子，保持像素人像风格
- 其余条目使用固定语义 seed，dicebear pixel-art 风格渲染为不同的像素图案
- 用户在下拉菜单点击「切换头像」循环遍历，索引持久化至 `localStorage`（key: `cyber_avatar_idx`）

### 6.2 成员列表头像

探测蒙层中的成员头像以昵称字符串直接作为 seed 请求 dicebear，保证同一昵称每次渲染结果一致。

---

## 7. 身份认证生命周期修复（Phase-3）

### 7.1 退出链路 Bug（已修复）

**旧方案问题**：`logout()` 只清除 localStorage，`loginSeq` 不变，`RoomChat` 的 `useEffect([roomId, loginSeq])` 不重跑，WebSocket 连接仍保持 OPEN，用户退出后依然可以发消息。

**修复方案**：退出时同步 `setLoginSeq(n => n + 1)`，与登录时路径完全对称：

```
用户点击「终止当前进程」
  → 清除 localStorage（token / name）
  → setIsLoggedIn(false)
  → setCyberName(null)
  → setLoginSeq(n => n + 1)     ← ★ 新增，触发 RoomChat effect 重跑
  → navigate('/chat/sector-001')

RoomChat useEffect([roomId, loginSeq]) 重跑
  → 读取 token 为空
  → setChannelState('offline')
  → wsRef.current?.close()       ← WS 正式关闭
  → setMemberList([])            ← 成员列表清空
  → input disabled，发送按钮置灰
```

### 7.2 离线状态感知 UI

`channelState !== 'online'` 时：
- 输入框 `disabled`，占位符切换为 `[ 链路断开 · 无法发送 ]`，文字变红透明
- 执行传输按钮 `disabled`，`opacity: 0.38`，`filter: saturate(0.2)`，`animation: none`
- CSS 类：`.cmd-input-offline` / `.cmd-exec-btn-offline`

---

## 8. 前端核心状态结构（Phase-3 全量）

### 8.1 App.tsx 状态

| 状态 | 类型 | 用途 |
|------|------|------|
| `isLoggedIn` | `boolean` | 控制 UI 认证区渲染 |
| `cyberName` | `string \| null` | 展示当前身份密匙 |
| `showLogin` | `boolean` | 控制登录弹层 |
| `noisePhase` | `0-3` | 每 170ms 随机，驱动头像/按钮微抖动 |
| `chatHeight` | `string` | `calc(100vh - headerH - 46px)`，JS 精确计算 |
| `loginSeq` | `number` | 登录/退出时 +1，触发 RoomChat WS 重连/断开 |
| `avatarIdx` | `number` | 头像池当前索引，持久化至 localStorage |

### 8.2 RoomChat.tsx 状态机

```
channelState: 'switching' | 'online' | 'offline'
  switching → 遮罩层 + 历史同步中（或切房动画中）
  online    → WS 已连通，输入可用
  offline   → WS 断开 / token 缺失，输入禁用

messages: ChatMessage[]
  ├── type: 'system' → systemMessages（useMemo）→ SYS://FEED 区
  └── type: 'chat'   → userMessages（useMemo）→ USR://STREAM 区

memberList: string[]   ← 历史 join/leave 扫描初始化 + 实时 WS 维护
showMembers: boolean   ← 控制探测蒙层显示
```

### 8.3 ChatMessage 类型（Phase-3 扩展）

```typescript
type SystemKind = 'join' | 'leave' | 'generic'

type ChatMessage = {
  id:           string
  type:         'chat' | 'system'
  systemKind?:  SystemKind     // system 消息细分，用于视觉分级
  sender?:      string
  content:      string
  timestamp:    string         // ISO 8601 UTC
  isHistory?:   boolean        // true → animate-pulse-once 入场动画
  expiresAt?:   number         // unix ms，仅实时 chat 消息有，system/history 无
  dissolving?:  boolean        // true → 触发 msg-dissolve 像素散开动画
}
```

---

## 9. 移动端适配（Phase-3 补充）

新增断点压缩，在 Header 区最为明显：

| 断点 | 变化 |
|------|------|
| `≤ 480px` | `.header` padding 8px，`.title` 字号 20px，`.tag` 隐藏，头像缩为 32px |
| `≤ 360px` | `.title` 字号 17px，头像缩为 28px |

命令面板在 `≤ 359px` 时已有 `flex-direction: column` 垂直堆叠（Phase-2 保留）。

---

## 10. API 接口速查表（Phase-3，无新增接口）

| 方法 | 路径 | 描述 |
|------|------|------|
| `POST` | `/api/auth/send-key` | 发送验证码（后端打印控制台） |
| `POST` | `/api/auth/verify` | 验证码核验 → 签发 JWT + cyber_name |
| `WS` | `/api/ws/{room_id}?token=` | 实时聊天 WebSocket（广播含 online_count） |
| `GET` | `/api/chat/history/{room_id}?limit=200` | 拉取历史聊天记录 |
| `GET` | `/health` | 心跳探针（DB + Cache 状态） |

---

## 11. 已落地完整清单

### ✅ Phase-1 完成（见 ARCHITECTURE_v1.md）

- FastAPI WebSocket 多房间广播架构
- JWT 鉴权（HS256，24h）
- 四扇区预设（sector-001/404/777/999）
- 历史消息 HTTP 拉取 + 流式渲染动画
- 基础像素赛博 UI 风格建立

### ✅ Phase-2 完成（见 ARCHITECTURE_v2.md）

- 子路径部署三层坐标对齐（Vite base + Router basename + nginx SPA fallback）
- 房间切换使用 React Router navigate，修复 basename 丢失
- 数据残响分界线（历史/实时消息可见边界）
- 在线人数后端真实统计（`online_count` 随广播下发）
- 登录后自动重连（`loginSeq` prop 触发 effect 重跑）
- 命令面板移动端除魔（`-webkit-appearance`, `touch-action`, 16px 字号）
- 像素赛博按钮 + 传送登录按钮（CRT 动效体系）
- 区头标题栏 CSS 类化（发光 + 扫描线 + 状态感知）
- 消息行隔行视觉区分（青/紫双色系）
- 时间戳非当天显示日期前缀
- GitHub Actions CI/CD

### ✅ Phase-3 完成（本文档）

- **消息 1 分钟生命周期**：`expiresAt` + 5s 扫描定时器 + `msg-dissolve` 像素散开动画
- **三区布局**：公告区 15% / 系统消息 15% / 用户消息 flex:1，含公告轮播组件
- **头像池扩展**：11 种 dicebear pixel-art 头像可循环，索引持久化
- **扇区成员探测**：历史快照扫描初始化 + 实时 WS 维护 + 做旧蒙层
- **系统消息三色分级**：join 绿 / leave 红橙 / generic 琥珀黄，前缀图标差异化
- **消息行内排版**：用户名 + 时间 + 内容 inline，行高撑开，去除双行拥挤感
- **退出链路修复**：`logout()` 同步 `loginSeq+1`，WS 彻底关闭，输入区离线置灰
- **移动端 Header 压缩**：两个断点（480px / 360px）逐级压缩

---

## 12. Phase-4 待建

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产安全加固 | 移除万能密码 `0000`，轮换 `JWT_SECRET`，CORS_ORIGINS 精确注入 |
| P0 | PostgreSQL 正式接入 | 完善 `db/postgres_provider.py`，执行 schema 迁移，替换内存存储 |
| P0 | 公告 API 化 | `GET /api/announcements`，后端管理员下发，替换前端静态数组 |
| P1 | 成员列表 API 化 | `GET /api/ws/rooms/{room_id}/members`，后端返回真实连接用户列表，替换字符串解析方案 |
| P1 | WS 心跳保活 | 客户端 ping / 服务端 pong，防长连接被基础设施断开（Nginx 60s 超时） |
| P1 | AI 气氛组 Agent | 封装于 `/backend/services/ai_agent.py`，定时发送赛博风格语录，禁止污染主路由 |
| P1 | 内容安全拦截 | 填充 `content_moderation` 占位函数，接入关键词过滤或第三方 API |
| P2 | 历史消息分页 | `before_timestamp` / `cursor` 参数，支持向上翻页加载更早记录 |
| P2 | 消息去重 | 切房边界 WS 与历史重叠时，`timestamp+sender+content` 联合去重 |
| P2 | 消息生命周期服务端同步 | 后端在存储时附加 TTL，历史接口不返回已过期消息，前端 expiresAt 改为服务端下发 |
| P2 | PWA / 离线缓存 | Service Worker，添加到桌面体验 |

---

*本文档生成于 Phase-3 开发完结节点，冻结当前架构共识。*  
*后续重大架构变更请同步更新本文件或新建 `ARCHITECTURE_v4.md`。*
