# ARCHITECTURE_v2.md
# 2000.exe · 系统架构快照 · Phase-2 记忆转储

> **文档定位**：在 Phase-1 基础上冻结本阶段所有实现变更，覆盖子路径部署、移动端适配、UI 重构、在线人数真实统计等新增设计决策。  
> **撰写原则**：记录"为什么这么设计"与"关键数据流"，不默写大段代码。  
> **更新时间**：2026-04-01  
> **仓库**：https://github.com/houkemian/cyber-chat  
> **前序文档**：[ARCHITECTURE_v1.md](./ARCHITECTURE_v1.md)

---

## 0. 世界观 · 系统哲学（继承 v1，补充变更）

> 这不是一个普通的聊天室。这是一个在千禧年末世数字荒野中燃烧的**赛博树洞**。
> 每个接入的终端都是匿名的，每条消息都是一次短暂的数据残响。

Phase-2 核心新增：

- **子路径部署**：前端以 `/cyber-chat/` 为基座挂载于主域名子路径，与宿主 Nginx 网关共存。
- **命令面板重构**：输入区彻底移除移动端系统默认样式，统一为像素赛博终端美学。
- **数据残响分界线**：用户进入房间后，历史快照与实时信流之间插入可见分割线，标记接入时刻。
- **在线人数真实化**：废弃前端字符串计数，改由后端在每次上下线广播时下发真实连接数。

---

## 1. 技术栈总览（Phase-2 变更列）

| 层级 | 技术 | Phase-2 变更 |
|------|------|------|
| 前端框架 | React 18 + TypeScript + Vite | `vite.config.ts` 新增 `base: '/cyber-chat/'` |
| 前端路由 | React Router v6 `BrowserRouter` | 新增 `basename="/cyber-chat"` |
| 容器化 | Docker Compose + nginx:alpine | 新增自定义 `nginx.conf`，挂载覆盖 `default.conf` |
| CI/CD | GitHub Actions SCP + SSH | SCP source 补充 `frontend/nginx.conf` |
| 实时通讯 | FastAPI WebSocket | 广播消息新增 `online_count` 字段 |

完整技术栈见 ARCHITECTURE_v1.md §1。

---

## 2. 子路径部署架构（Phase-2 核心新增）

### 2.1 为什么需要子路径部署

主域名 `dothings.one` 的根路径已被占用，前端必须挂载在 `/cyber-chat/` 子路径下，后端 API 通过宿主 Nginx 以 `/cyber-api/` 转发至容器内部 8000 端口。

### 2.2 三层坐标对齐

子路径部署的陷阱在于三套"坐标系"必须同时校准，任何一层偏差都会导致资源加载失败或路由跳转丢失前缀：

```
┌─────────────────────────────────────────────┐
│  层1：静态资源基座（vite.config.ts）          │
│  base: '/cyber-chat/'                        │
│  → 打包后所有 JS/CSS import 路径自动带前缀    │
├─────────────────────────────────────────────┤
│  层2：路由导航基座（main.tsx）                │
│  <BrowserRouter basename="/cyber-chat">      │
│  → navigate('/chat/xxx') 实际生成           │
│    /cyber-chat/chat/xxx                      │
├─────────────────────────────────────────────┤
│  层3：SPA Fallback（nginx.conf）             │
│  location /cyber-chat/ {                     │
│    try_files $uri /cyber-chat/index.html;   │
│  }                                           │
│  → 刷新任意子路径均返回 index.html           │
└─────────────────────────────────────────────┘
```

**关键教训**：`handleSwitchSector` 最初使用 `window.location.assign('/chat/xxx')` 直接跳转，这是浏览器原生 API，完全不知道 `basename`，会跳到裸路径 `/chat/xxx` 而非 `/cyber-chat/chat/xxx`。修复方案：强制使用 React Router 的 `navigate('/chat/xxx')`，由 Router 自动补全前缀。

### 2.3 网络信号链路环境切换

```typescript
// config/api.ts
const isLocalHost = hostname === 'localhost' || hostname === '127.0.0.1'

// 本地开发：直连后端开发服务器
HTTP_BASE_URL = isLocalHost ? 'http://localhost:8001' : 'https://dothings.one/cyber-api'
WS_BASE_URL  = isLocalHost ? 'ws://localhost:8001'   : 'wss://dothings.one/cyber-api'

// 下游常量（无多余斜杠）
API_AUTH_URL    = `${HTTP_BASE_URL}/api/auth`
CHAT_WS_BASE_URL = `${WS_BASE_URL}/api/ws`
```

> **为什么 8001？** 本地开发时 8000 端口偶发 TIME_WAIT 僵占（Windows TCP 保留约 60s），切到 8001 规避冲突。生产环境由 Nginx 反代，端口对前端透明。

### 2.4 Docker Compose 服务拓扑

```
宿主 Nginx（dothings.one）
  ├── /cyber-chat/*  → 转发至  frontend容器:20001
  │                   nginx 做 SPA fallback
  └── /cyber-api/*   → 转发至  backend容器:20002
                        FastAPI Uvicorn

frontend 容器 (nginx:alpine)
  挂载: ./frontend/dist  → /usr/share/nginx/html/cyber-chat
  挂载: ./frontend/nginx.conf → /etc/nginx/conf.d/default.conf

backend 容器 (python:3.12)
  端口: 20002:8000
  环境: DATABASE_URL, ENV=production, JWT_SECRET, CORS_ORIGINS
```

---

## 3. 身份与鉴权机制（继承 v1，无变更）

见 ARCHITECTURE_v1.md §3。核心链路不变：手机号 → 后端生成验证码打印控制台 → 验证 → 签发 JWT（HS256, 24h）→ 前端存 localStorage。

**万能密码**：`sms_code = "0000"` 开发专用，**生产必须移除**。

---

## 4. 多扇区通讯链路（Phase-2 更新：在线人数）

### 4.1 在线人数真实统计（Phase-2 新增）

**旧方案的问题**：前端监听 system 消息字符串做 `+1/-1`，初始值硬编码为 1，切房后重置为 1，完全不准确，且与实际连接数无关。

**新方案**：后端在每次连接/断开后，通过 `ws_manager.get_room_count(room)` 直接查询连接池长度，附加到 system 广播消息中：

```python
# 连接时
{
    "type": "system",
    "content": "[系统]: 终端 <cyber_name> 已接入扇区 <room>。",
    "timestamp": "...",
    "online_count": ws_manager.get_room_count(room)  # ← 新增
}

# 断开时（disconnect 之后计数已减少）
{
    "type": "system",
    "content": "[系统]: 终端 <cyber_name> 已断开扇区 <room>。",
    "timestamp": "...",
    "online_count": ws_manager.get_room_count(room)  # ← 断开后的真实值
}
```

前端收到后直接赋值，不再做加减运算：

```typescript
if (raw.type === 'system' && raw.online_count !== undefined) {
    setOnlineCount(raw.online_count)
}
```

### 4.2 前端房间切换（Phase-2 修正）

切房触发时序（`handleSwitchSector`）：

```
点击 Tab
  → setChannelState('switching')    // 立即遮罩
  → wsRef.current?.close()          // 主动断开旧 WS
  → setChaosFx(true)                // CRT 断流特效（600ms）
  → setTimeout 600ms
      → navigate('/chat/:new_room_id')  // ← Phase-2 修正：用 Router navigate
      → setChaosFx(false)               //   而非 window.location.assign（会丢失 basename）
```

路由变化 → `roomId` 变化 → `useEffect([roomId, loginSeq])` 触发 → 进入数据残响同步流程。

### 4.3 并发安全策略（继承 v1）

`wsSeqRef`（单调递增）防并发污染：每次新房间初始化时 `++seq`，所有 WS 回调检查 `seq === wsSeqRef.current`，过期异步结果自动丢弃。

---

## 5. 数据残响机制（Phase-2 新增：分界线与登录重连）

### 5.1 数据残响分界线（Phase-2 新增）

**设计目标**：用户进入房间后，能清晰感知"历史缓存"与"我接入后的实时信流"之间的边界。

```
分界线显示条件：
  !isHistorySyncing && lastHistoryIdx >= 0

  lastHistoryIdx = userMessages.map(m => m.isHistory).lastIndexOf(true)

渲染位置：
  userMessages.map((msg, idx) => (
    <>
      <RoomMessageLine ... />
      {showDivider && idx === lastHistoryIdx && (
        <div className="data-echo-divider">DATA ECHO · 数据残响 ▾</div>
      )}
    </>
  ))
```

分界线固定在最后一条历史消息之后。历史同步期间（`isHistorySyncing = true`）不显示，同步完成后出现并永久保留，后续实时消息追加在分界线之后。

### 5.2 登录后自动重连（Phase-2 新增）

**问题**：`RoomChat` 主 effect 依赖 `[roomId, loginSeq]`。用户未登录时 effect 运行一次（token 为空，进入 offline 分支），关闭弹层后 `roomId` 未变，effect 不再重跑，WS 无法建立。

**修复**：在 `App.tsx` 中维护 `loginSeq: number`，登录成功时 `setLoginSeq(n => n + 1)`，通过 prop 传入 `RoomChat`。`loginSeq` 变化触发 effect 重跑，重新读取 token，建立 WS 链路。

```
用户登录成功
  → handleLoginSuccess(name)
  → setIsLoggedIn(true)
  → setShowLogin(false)
  → setLoginSeq(n => n + 1)    // ← 触发 RoomChat 重连
  → navigate('/chat/sector-001')
```

### 5.3 分阶段时序（继承 v1，补充注解）

```
Phase A - 初始化（roomId 或 loginSeq 变化触发）
  清空 messages / rawHistory / syncRenderedCount
  setIsHistorySyncing(true)
  关闭旧 WS，wsSeqRef++

Phase B - HTTP 拉取历史快照
  GET /api/chat/history/{room_id}?limit=200
  ← list[ChatMessage]，map 为 isHistory: true

Phase C - 流式分批渲染（数据残响动画）
  setInterval 50ms：每次 append 3 条
  setSyncRenderedCount(cursor)   // 进度条实时更新

Phase D - 同步完成 → 接入实时链路
  clearInterval()
  setIsHistorySyncing(false)     // ← 此时数据残响分界线出现
  openRealtimeLink()             // new WebSocket(...)
  setChannelState('online')
```

---

## 6. 命令面板重构（Phase-2 核心新增）

### 6.1 移动端除魔清单

| 问题 | 修复方案 |
|------|------|
| iOS 系统默认圆角/渐变 input | `-webkit-appearance: none` |
| iOS 自动缩放（font-size < 16px） | `font-size: 16px`（`cmd-input`） |
| 双击缩放 | `touch-action: manipulation` |
| 点击蓝色高亮框 | `-webkit-tap-highlight-color: transparent` |
| 自动填充弹出遮盖 UI | `autoComplete="off" autoCorrect="off" autoCapitalize="off" spellCheck={false}` |

### 6.2 命令面板结构

```
<div className="cmd-panel">                    ← 外层：flex 布局，<360px 垂直堆叠
  <label className="cmd-input-wrap">           ← 像素凹陷边框（Win98 风格），扫描线 ::before
    <span className="cmd-prompt">&gt; //</span>  ← 固定提示符，不可选中
    <input className="cmd-input" ... />        ← 荧光绿，16px，除魔完毕
  </label>
  <button className="cmd-exec-btn">            ← 像素凸起边框，噪点 + 辉光双层伪元素
    <span>[ 执行传输 X-MISSION ]</span>
  </button>
</div>
```

**按钮动效**：
- 常态：`xmission-idle` — 霓虹紫边框与发光在步进闪烁（粉紫 ↔ 蓝紫）
- Active：`xmission-chromatic` — 色差分离 keyframes，红/青通道各帧错位 ±2px，模拟 CRT 信号撕裂

### 6.3 传送登录按钮（`.auth-btn-teleport`）

区别于 `auth-btn` 体系，完全独立：
- 背景透明，`border: 2px solid #ff00ff`（霓虹粉）
- 文案：`[ 传送：GO! ]`
- 常态：`teleport-idle` — 粉 `#FF00FF` ↔ 蓝 `#00FFFF` 整体切换
- Hover：`teleport-glitch` — `text-shadow` 通道横向偏移，故障抖动

---

## 7. UI 视觉体系（Phase-2 新增组件）

### 7.1 区头标题栏（`.panel-header-sys` / `.panel-header-usr`）

两个消息区的头部由 Tailwind 任意值迁移至专用 CSS 类，确保 `text-shadow` / `box-shadow` 稳定渲染：

| 元素 | `SYS://FEED` | `USR://STREAM` |
|------|------|------|
| 指示灯 `.dot` | 琥珀黄呼吸 | 在线青色呼吸 / 断线深蓝静止 |
| 主标题 `.title` | `text-shadow` 琥珀发光 | `text-shadow` 青色发光 |
| 流向符 `.arrows` | `▸▸` 低透 | `▸▸` 低透 |
| 右侧徽章 `.badge` | `◈ MONITOR`（常亮） | `◈ LIVE`（联动 channelState） |
| 背景 | 暖色渐变底 + 扫描线 `::after` | 冷色渐变底 + 扫描线 `::after` |

### 7.2 消息行隔行区分

```
偶数行 (.msg-row-even)：
  border-bottom: 1px dashed rgba(34, 211, 238, 0.18)  // 青色底线
  sender 颜色：text-cyan-400

奇数行 (.msg-row-odd)：
  border-left: 2px solid rgba(188, 0, 255, 0.35)      // 霓虹紫左竖线
  background: rgba(188, 0, 255, 0.03)                 // 极淡紫底色
  sender 颜色：text-fuchsia-300
  hover：border-left 加亮至 0.65 不透明度
```

### 7.3 时间戳智能显示

```typescript
function toClock(iso: string): string {
  // 当天消息：14:32
  // 非当天：  03-28 14:32
}
```

---

## 8. 前端核心状态结构（Phase-2 全量）

### 8.1 App.tsx 状态

| 状态 | 类型 | 用途 |
|------|------|------|
| `isLoggedIn` | `boolean` | 控制 UI 认证区渲染 |
| `cyberName` | `string \| null` | 展示当前身份密匙 |
| `showLogin` | `boolean` | 控制登录弹层 |
| `noisePhase` | `0-3` | 每 170ms 随机，驱动头像/按钮微抖动 CSS 属性选择器 |
| `chatHeight` | `string` | `calc(100vh - headerH - 46px)`，JS 精确计算防输入框被顶走 |
| `loginSeq` | `number` | 登录成功时 +1，传入 RoomChat 触发 WS 重连 |

### 8.2 RoomChat.tsx 状态机

```
channelState: 'switching' | 'online' | 'offline'
  switching → 遮罩层 + 历史同步中
  online    → WS 已连通
  offline   → WS 断开 / token 缺失

isHistorySyncing: boolean
  true  → 进度条可见，WS 未建立，数据残响分界线隐藏
  false → 进度条隐藏，WS 已建立，数据残响分界线出现（若有历史）

messages: ChatMessage[]       ← system + chat 混合渲染列表
rawHistory: ChatMessage[]     ← HTTP 快照缓冲区（流式渲染期间存在）
systemMessages: ChatMessage[] ← useMemo 过滤 → SYSTEM FEED 区
userMessages: ChatMessage[]   ← useMemo 过滤 → USER STREAM 区
syncRenderedCount: number     ← 进度条分子（最大 200）
onlineCount: number           ← 后端 online_count 字段直接赋值
```

### 8.3 ChatMessage 类型

```typescript
type ChatMessage = {
  id:        string       // hist-${room}-${idx}-${ts} | chat/sys-${ts}-${random}
  type:      'chat' | 'system'
  sender?:   string
  content:   string
  timestamp: string       // ISO 8601 UTC
  isHistory?: boolean     // true → animate-pulse-once 入场动画
}
```

---

## 9. API 接口速查表（Phase-2 全量）

| 方法 | 路径 | 描述 |
|------|------|------|
| `POST` | `/api/auth/send-key` | 发送验证码（后端打印控制台） |
| `POST` | `/api/auth/verify` | 验证码核验 → 签发 JWT + cyber_name |
| `WS` | `/api/ws/{room_id}?token=` | 实时聊天 WebSocket（广播含 online_count） |
| `GET` | `/api/chat/history/{room_id}?limit=200` | 拉取历史聊天记录 |
| `GET` | `/health` | 心跳探针（DB + Cache 状态） |

---

## 10. 已落地 · 后续待建

### ✅ Phase-2 新增完成

- 子路径部署三层坐标对齐（Vite base + Router basename + nginx SPA fallback）
- 房间切换使用 React Router navigate，修复 basename 丢失
- 数据残响分界线（历史/实时消息可见边界）
- 在线人数后端真实统计（`online_count` 随广播下发）
- 登录后自动重连（`loginSeq` prop 触发 effect 重跑）
- 命令面板移动端除魔（`-webkit-appearance`, `touch-action`, 16px 字号）
- 像素赛博按钮（`cmd-exec-btn`：噪点 + 辉光 + 色差分离点击动效）
- 传送登录按钮（`auth-btn-teleport`：霓虹粉蓝故障抖动）
- 区头标题栏 CSS 类化（`panel-header-sys/usr`：发光 + 扫描线 + 状态感知）
- 消息行隔行视觉区分（青/紫双色系）
- 时间戳非当天显示日期前缀
- Tab 栏横向滚动（修复手机端换行）
- 页面 title 改为 `2000.exe`
- GitHub Actions CI/CD（SCP 传输 + Docker Compose 重启）

### 🔜 Phase-3 建议

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产环境安全加固 | 移除万能密码 `0000`，轮换 `JWT_SECRET`，CORS_ORIGINS 精确注入 |
| P0 | PostgreSQL 接入 | 完善 `db/postgres_provider.py`，执行 schema 迁移 |
| P1 | AI 气氛组 Agent | 独立封装于 `/backend/services/ai_agent.py`，禁止污染主路由 |
| P1 | 内容安全拦截 | 填充 `content_moderation` 占位函数 |
| P1 | WS 心跳保活 | 客户端 ping / 服务端 pong，防长连接被基础设施断开 |
| P2 | 历史消息分页 | `before_timestamp` / `cursor` 参数，支持向上翻页 |
| P2 | 消息去重 | 切房边界时刻 WS 与历史重叠，`timestamp+sender+content` 联合去重 |
| P2 | PWA / 离线缓存 | Service Worker，壳子感更强 |

### ✅ Phase-3 已完成

- **消息生命周期**：实时消息（	ype: 'chat'）接收时附加 expiresAt = Date.now() + MESSAGE_LIFETIME_MINUTES * 60000（默认 1 分钟，配置常量在 RoomChat.tsx 顶部）。每 5s 扫描一次，到期先标记 dissolving: true，触发 msg-dissolve CSS keyframe（像素化散开 + 色差分离，800ms），动画结束后从 state 彻底移除。历史消息不设 expiresAt，永久保留。
- **头像池扩展**：App.tsx 新增 AVATAR_POOL 数组，含 1 个动态人像（seed = cyberName）+ 10 个物件头像（小雨伞、仙人掌、小电脑、磁碟片、游戏机、卫星锅、咖啡杯、外星舱、磁带机、机器人），全部使用 dicebear pixel-art 风格。用户可在下拉菜单点击「切换头像」循环遍历，当前索引持久化至 localStorage（key: cyber_avatar_idx）。
- **查看成员按钮**：命令面板新增 .cmd-members-btn，位于输入框左侧。点击后弹出 .members-overlay-mask 居中蒙层，列出当前房间在线匿名昵称（含像素头像）。成员列表通过监听 system 消息中「已接入/已断开」字符串实时维护（memberList state），无需额外 API。
- **公告区新增 + 布局重构**：聊天主体由 2 区改为 3 区，竖向比例为公告区 15% / 系统消息区 15% / 用户消息区 flex:1（约 65%），输入区固定高度约 5%。公告区（AnnouncementPanel）包含静态公告数组 ANNOUNCEMENTS，每 6s 自动轮播并带淡入淡出动效，底部可点击圆点手动切换。

### 🔜 Phase-4 建议

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产环境安全加固 | 移除万能密码  000，轮换 JWT_SECRET，CORS_ORIGINS 精确注入 |
| P0 | PostgreSQL 接入 | 完善 db/postgres_provider.py，执行 schema 迁移 |
| P0 | 公告 API 化 | 新增 GET /api/announcements 接口，由后端下发，替换前端静态数组 |
| P1 | 成员列表 API 化 | 新增 GET /api/ws/rooms/{room_id}/members 接口，替换字符串解析方案 |
| P1 | AI 气氛组 Agent | 独立封装于 /backend/services/ai_agent.py，禁止污染主路由 |
| P1 | 内容安全拦截 | 填充 content_moderation 占位函数 |
| P1 | WS 心跳保活 | 客户端 ping / 服务端 pong，防长连接被基础设施断开 |
| P2 | 历史消息分页 | efore_timestamp / cursor 参数，支持向上翻页 |
| P2 | 消息去重 | 切房边界时刻 WS 与历史重叠，	imestamp+sender+content 联合去重 |
| P2 | PWA / 离线缓存 | Service Worker，壳子感更强 |

---

*本文档生成于 Phase-2 开发完结节点，冻结当前架构共识。*  
*后续重大架构变更请同步更新本文件或新建 `ARCHITECTURE_v3.md`。*

