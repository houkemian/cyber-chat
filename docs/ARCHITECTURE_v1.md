# ARCHITECTURE_v1.md
# 2000.exe · 系统架构快照 · Phase-1 记忆转储

> **文档定位**：冻结当前实现共识，防止后续开发上下文漂移。  
> **撰写原则**：记录"为什么这么设计"与"关键数据流"，不默写大段代码。  
> **更新时间**：2026-03-31  
> **仓库**：https://github.com/houkemian/cyber-chat

---

## 0. 世界观 · 系统哲学

> 这不是一个普通的聊天室。这是一个在千禧年末世数字荒野中燃烧的**赛博树洞**。
> 每个接入的终端都是匿名的，每条消息都是一次短暂的数据残响。

核心设计哲学：

- **匿名优先**：前端永远不存储真实手机号，只持有 JWT + 随机生成的 `cyber_name`。
- **容错为王**：Redis 宕机 → 降级内存缓存。DB 写入失败 → 不阻断实时广播。
- **链路可替换**：DB 层（SQLite ↔ PostgreSQL）和 Cache 层（Memory ↔ Redis）均有抽象接口，切换只需改环境变量。

---

## 1. 技术栈总览

| 层级 | 技术 | 备注 |
|------|------|------|
| 前端框架 | React 18 + TypeScript + Vite | 函数组件 + Hooks |
| 前端样式 | TailwindCSS + 全局 CSS | Y2K 手工样式 |
| 前端路由 | React Router v6 | `/chat/:room_id` |
| HTTP 客户端 | axios | 历史消息拉取 |
| 后端框架 | FastAPI + Uvicorn | 全异步 `async def` |
| 实时通讯 | FastAPI WebSocket | 原生 WS，无第三方 |
| 数据校验 | Pydantic v2 BaseModel | 严禁裸字典传参 |
| 数据库 | SQLite（默认）/ PostgreSQL | 可环境变量切换 |
| 缓存 | 内存 deque（默认）/ Redis | 可环境变量切换 |
| 鉴权 | JWT HS256 / PyJWT | 24h 有效期 |
| 环境配置 | python-dotenv + AppSettings | 统一从 `.env` 注入 |

---

## 2. 核心世界观 · UI 规范

### 2.1 Y2K 赛博终端美学

项目视觉语言严格对标 **千禧年复古赛博风（Y2K Cyberpunk）**，核心色系：

| 色名 | HEX | 用途 |
|------|-----|------|
| 霓虹紫 | `#bc00ff` | 主标题、强调态 |
| 赛博蓝 | `#00f0ff` | 在线状态、链路发光 |
| 荧光绿 | `#39ff14` | 输入框、命令行文本 |
| 琥珀黄 | `#fde68a` | 系统消息区 |

**视觉组件规范**：

- Win95/98 立体边框：`border-t-white border-l-white border-r-gray-700 border-b-gray-700`（凸起）/ 反向（凹陷）
- CRT 扫描线：`global-chat-grain` CSS 类，`::before` 叠加 repeating-linear-gradient 模拟扫描纹理
- 发光特效：`drop-shadow` / `box-shadow` 配合高饱和色，模拟 CRT 屏幕辉光
- 静电噪声：`static-grain` 关键帧动画，按像素 translate 抖动
- 赛博风滚动条：全局 `::-webkit-scrollbar`，三色渐变滑块（蓝→紫→绿），直角无圆角

### 2.2 命令控制台布局策略（"沉底"问题根因与解法）

**为什么输入框老是被顶走？**

CSS `h-full` 链路在父容器没有显式 `height` 时全部失效。`.container` 类只有 `max-width`，导致整条高度链路断裂，消息内容可以无限向下撑开页面。

**最终解法（两层硬锁定）**：

```
App.tsx
  └─ <section style={{ height: chatHeight }}>   ← JS 精确计算：100vh - header实测高度 - padding - gap
       └─ <RoomChat embedded />
            └─ 根容器 style={{ height:'100%', display:'flex', flexDirection:'column', overflow:'hidden' }}
                 ├─ Tab 栏：shrink-0（固定）
                 ├─ 消息主区：flex:1, minHeight:0（关键！消除 flex 默认最小内容高度）
                 │    ├─ SYSTEM FEED：固定 20% / min 96px，内部 overflow-y:auto
                 │    └─ USER STREAM：flex:1, minHeight:0，内部 overflow-y:auto ← 唯一滚动层
                 ├─ 同步进度条：shrink-0（条件渲染）
                 └─ 输入框区：shrink-0（永远钉底）
```

> **关键洞见**：Flex 子项的默认 `min-height` 是 `auto`（内容高度），必须显式设置 `minHeight: 0` 才能让容器被压缩而不是撑开父级。

---

## 3. 身份与鉴权机制

### 3.1 数据流向

```
[用户] 输入手机号
  → POST /api/auth/send-key  { phone_number }
  ← { ok: true }  (密匙打印至后端控制台，MVP 阶段)

[用户] 输入验证码
  → POST /api/auth/verify  { phone_number, sms_code }
  ← { token: "<JWT>", cyber_name: "<随机网名>" }

[前端] localStorage.setItem('cyber_token', token)
       localStorage.setItem('cyber_name', cyber_name)
```

### 3.2 JWT 结构

```json
{
  "phone_number": "138xxxxxxxx",
  "cyber_name":   "夜色温柔°孤独患者",
  "exp":          1743000000
}
```

- 算法：`HS256`
- 有效期：24 小时
- 签名密钥：环境变量 `JWT_SECRET`（开发默认值 `dev-secret-change-me-in-prod`）

### 3.3 设计决策

- **手机号永远不落前端**：前端只缓存 token 和 cyber_name，手机号仅在后端流转。
- **cyber_name 一人一号**：同一手机号首次登录后由后端随机生成并写库，后续直接查库返回，保证身份稳定性。
- **万能密码**：`sms_code = "0000"` 在任何情况下直接通过验证，供开发联调使用。**生产环境必须移除此逻辑。**
- **WS 鉴权三档**：WebSocket 连接时按优先级读取 token：Query `?token=` > Header `Authorization: Bearer` > Header `X-Token`。

---

## 4. 多扇区通讯链路

### 4.1 后端连接管理器（`ConnectionManager` 单例）

所有房间共享一个进程级单例 `ws_manager`，核心数据结构：

```python
rooms:    dict[room_id, list[WebSocket]]    # 在线连接池，按房间隔离
histories: dict[room_id, deque(maxlen=200)] # 热历史缓存，内存环形队列
_room_locks: dict[room_id, asyncio.Lock]    # 每房间独立锁，保证并发安全
```

**并发安全策略**：
- 连接注册/注销：在 `room_lock` 内操作列表
- 广播：在锁内快照连接列表（`list(...)`），在**锁外**执行真实网络发送，降低锁占用时长
- 历史写入：在 `room_lock` 内写 deque，再在锁外写 Redis

### 4.2 消息广播数据流

```
用户发送文本
  → WS.receive_text()
  → content_moderation(raw_text)  [占位，待接入风控]
  → 构造 message_payload { type, sender, content, timestamp }
  → db.save_chat_message(...)      [异步写库，失败不阻断]
  → ws_manager.broadcast_json(payload, room_id)
       → _cache_history()           [仅 type=chat 进缓存]
           → deque.append()         [内存]
           → Redis LPUSH + LTRIM    [持久化，失败降级]
       → 广播到房间内所有在线 WS
```

**系统消息不进历史**：上下线广播（`type=system`）实时发送，但被 `_cache_history` 中的 `type != "chat"` 守卫拦截，不写入 Redis / deque，所以历史接口永远只返回用户聊天消息。

### 4.3 前端房间切换机制

切房触发时序（`handleSwitchSector`）：

```
点击 Tab
  → setChannelState('switching')    // 立即遮罩，防止旧消息残留
  → wsRef.current?.close()          // 主动断开旧 WS
  → setChaosFx(true)                // 触发 CRT 断流特效（600ms）
  → setTimeout 600ms → window.location.assign('/chat/:new_room_id')
```

路由变化 → `roomId` 变化 → `useEffect([roomId])` 触发 → 进入数据残响同步流程（见第 5 节）。

**防并发污染**：使用 `wsSeqRef`（单调递增序列号），每次新房间初始化时 `++seq`，所有 WS 回调和定时器都检查 `seq === wsSeqRef.current`，过期的异步结果自动丢弃。

---

## 5. 数据残响机制（历史流式渲染）

> 设计目标：用户切房后应感受到"历史数据从远端信道缓缓渗入终端"的视觉体验，而非生硬的列表刷新。WS 实时流在历史全部渲染完毕后才接入，避免消息乱序。

### 5.1 分阶段时序

```
Phase A - 切房初始化
  setMessages([])         // 清空旧消息
  setIsHistorySyncing(true)
  wsRef.close()           // 关旧连接

Phase B - HTTP 拉取历史快照
  GET /api/chat/history/{room_id}?limit=200
  ← list[{ type, sender, content, timestamp }]  // 正序，仅 type=chat
  normalizedHistory = response.data.map(item → ChatMessage { isHistory: true })

Phase C - 流式分批渲染（数据残响）
  setInterval(50ms):
    每次取 rawHistory[cursor .. cursor+3]
    setMessages(prev => [...prev, ...batch])
    setSyncRenderedCount(cursor)
    // 进度条实时更新：[ 同步中: 124/200 ]
    // 历史消息带 animate-pulse-once 动画（入场闪烁）

Phase D - 同步完成 → 接入实时链路
  clearInterval()
  setIsHistorySyncing(false)
  openRealtimeLink()       // new WebSocket(...)
  setChannelState('online')
```

### 5.2 后端历史接口

```
GET /api/chat/history/{room_id}?limit=200

读取优先级：
  1. Redis List `chat:history:{room_id}` (LRANGE 0 limit-1 → reverse → 正序返回)
  2. 内存 deque (服务重启后 Redis 无数据时兜底)

返回：list[RoomHistoryMessage]
  { type: "chat", sender: str, content: str, timestamp: ISO8601 }
```

**为什么先 HTTP 再 WS？**

若同时建立，历史消息与 WS 实时消息会并发到达前端，产生乱序和重复。HTTP 是同步快照，WS 是无限流；把快照先渲染完毕，再接入增量流，天然串行，无需客户端去重。

### 5.3 Redis 持久化策略

```
写入：LPUSH chat:history:{room_id} <json>
      LTRIM chat:history:{room_id} 0 199       ← 保持 200 条窗口
      （以上在同一 pipeline transaction 中执行）

读取：LRANGE chat:history:{room_id} 0 limit-1  ← Redis 存储为 LIFO，读完后 reverse 转正序

降级：Redis 不可用时 → 仅内存 deque，服务重启后历史清零（可接受，下次由 DB 归档支撑）
```

---

## 6. 基础设施抽象层

### 6.1 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DB_BACKEND` | `sqlite` | `sqlite` / `postgres` |
| `SQLITE_PATH` | `./data/cyber_chat.db` | SQLite 文件路径 |
| `POSTGRES_DSN` | `postgresql://...` | PostgreSQL 连接串 |
| `CACHE_BACKEND` | `memory` | `memory` / `redis` |
| `REDIS_DSN` | `redis://127.0.0.1:6379/0` | Redis 连接串 |
| `JWT_SECRET` | `dev-secret-change-me-in-prod` | **生产必改** |
| `CORS_ORIGINS` | 空（允许 localhost） | 生产环境精确注入 |

### 6.2 DB 抽象接口（`db/base.py`）

```python
save_chat_message(room_id, sender, content, timestamp)
list_chat_messages(room_id, limit) → list[dict]
create_user_profile(phone_number, cyber_name) → bool
get_user_cyber_name(phone_number) → str | None
healthcheck() → bool
```

### 6.3 Cache 抽象接口（`cache/base.py`）

```python
get(key) → Any | None
set(key, value, ttl_seconds?)
delete(key)
healthcheck() → bool
```

---

## 7. 前端核心状态结构

### 7.1 RoomChat 组件状态机

```
channelState: 'switching' | 'online' | 'offline'
  switching → 遮罩层覆盖，历史同步中
  online    → WS 已连通，正常收发
  offline   → WS 断开 / token 缺失

isHistorySyncing: boolean
  true  → 进度条可见，WS 未建立
  false → 进度条隐藏，WS 已建立或无历史

messages: ChatMessage[]           ← 渲染列表（system + chat 混合）
rawHistory: ChatMessage[]         ← HTTP 原始快照缓冲区（仅切房时存在）
systemMessages: ChatMessage[]     ← useMemo 过滤，渲染到 SYSTEM FEED 区
userMessages: ChatMessage[]       ← useMemo 过滤，渲染到 USER STREAM 区
syncRenderedCount: number         ← 进度条分子
```

### 7.2 ChatMessage 类型

```typescript
type ChatMessage = {
  id:        string           // 唯一键（历史: hist-${room}-${index}-${ts}，实时: chat/sys-${ts}-${random}）
  type:      'chat' | 'system'
  sender?:   string           // system 消息无 sender
  content:   string
  timestamp: string           // ISO 8601 UTC
  isHistory?: boolean         // true → 渲染时触发 animate-pulse-once 入场动画
}
```

### 7.3 localStorage 持久化字段

| Key | Value | 说明 |
|-----|-------|------|
| `cyber_token` | JWT 字符串 | 每次建立 WS 时读取 |
| `cyber_name` | 赛博网名 | 仅用于 UI 展示 |

---

## 8. API 接口速查表

| 方法 | 路径 | 描述 |
|------|------|------|
| `POST` | `/api/auth/send-key` | 发送验证码 |
| `POST` | `/api/auth/verify` | 验证码核验 → 签发 JWT |
| `WS` | `/api/ws/{room_id}?token=` | 实时聊天 WebSocket |
| `GET` | `/api/chat/history/{room_id}?limit=200` | 拉取历史聊天记录（仅 chat 消息） |
| `GET` | `/health` | 心跳探针（DB + Cache 状态） |

---

## 9. 当前已落地 · 后续待建

### ✅ 已完成（Phase 1）

- 匿名身份体系：手机号 → JWT → cyber_name 全链路
- 多扇区 WebSocket 隔离：4 个预设房间，独立连接池
- 数据残响机制：HTTP 历史快照 + 50ms 分批流式渲染 + WS 实时信号
- Redis 双写历史缓存（LPUSH/LTRIM 200 条窗口），服务重启持久化
- 基础设施可替换抽象（SQLite/PG、Memory/Redis）
- Y2K 赛博终端 UI：CRT 扫描线、静电噪声、Win95 立体边框、赛博风滚动条
- 双区消息分流：SYSTEM FEED（20%）/ USER STREAM（80%）
- 输入框绝对沉底（JS 动态 calc 高度锁定）

### 🔜 后续建议（Phase 2+）

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产环境安全加固 | 移除万能密码 `0000`，轮换 `JWT_SECRET` |
| P0 | PostgreSQL 接入 | 完善 `db/postgres_provider.py`，执行 schema 迁移 |
| P1 | AI 气氛组 Agent | 独立封装于 `/backend/services/ai_agent.py`，禁止污染主路由 |
| P1 | 内容安全拦截 | 填充 `content_moderation` 占位函数，接入敏感词/风控 SDK |
| P1 | CI/CD 流水线 | GitHub Actions → Docker Build → 云端部署 |
| P2 | 历史消息分页 | 增加 `before_timestamp` / `cursor` 参数，支持向上翻页 |
| P2 | WS 心跳保活 | 客户端 ping / 服务端 pong，防止长连接被基础设施强制断开 |
| P2 | 消息去重策略 | 切房边界时刻 WS 与历史消息重叠，用 `timestamp+sender+content` 联合去重 |

---

*本文档生成于 Phase-1 开发完结节点，冻结当前架构共识。*  
*后续重大架构变更请同步更新本文件或新建 `ARCHITECTURE_v2.md`。*
