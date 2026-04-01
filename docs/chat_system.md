# Chat System 技术快照（多房间 / Redis 历史缓存 / 转场特效）

> 项目：2000.exe（Cyber Dream Space）  
> 更新时间：2026-03-31  
> 范围：`/backend` WebSocket 与历史缓存、`/frontend` RoomChat 与转场特效

---

## 1. 后端多房间 WebSocket + 历史缓存（`utils/ws_manager.py`）

### 1.1 连接池 + 历史缓存模型

`ConnectionManager` 已从单大厅升级为**房间隔离结构**：

- `rooms: dict[str, list[WebSocket]]`
  - Key：`room_id`
  - Value：该房间当前在线的 WebSocket 列表
- `histories: dict[str, deque[maxlen=200]]`
  - Key：`room_id`
  - Value：该房间最近 200 条广播消息（内存环形队列）
- `redis list key: chat:history:{room_id}`
  - 通过 `LPUSH + LTRIM 0 199` 保持固定窗口

### 1.2 核心方法

- `connect(websocket, room_id)`
  - `accept()` 后将连接加入对应房间列表
  - 若房间不存在先创建空列表

- `disconnect(websocket, room_id)`
  - 从指定房间移除连接
  - 房间为空时自动 `pop`，避免空 Key 累积

- `broadcast_json(payload, room_id)`
  - 先写入房间 `deque(maxlen=200)`
  - 再同步写入 Redis List（写失败降级到仅内存）
  - 仅向目标房间广播
  - 房间不存在/为空时直接返回（防崩溃）
  - 单连接发送失败会被自动剔除（容错）
- `get_room_history(room_id, limit)`
  - 优先读 Redis 并转换为时间正序
  - Redis 不可用或无数据时回退内存队列

### 1.3 并发安全策略

- 每个房间使用独立 `asyncio.Lock`
- 连接池与历史缓存都在房间锁内做增删改，避免高并发下列表/队列竞争
- 广播时只在锁内复制快照，真实网络发送在锁外执行，降低锁占用时间

### 1.4 路由与隔离语义

`api/routes/chat.py` 当前使用：

- `@router.websocket("/ws/{room_id}")`

并在连接期做：

- 路径参数归一化：空值回退 `lobby`
- JWT 鉴权（Query/Header）与 `cyber_name` 提取
- 上下线系统消息限定在房间内广播  
  例：`[系统]: 终端 <cyber_name> 已接入扇区 <room_id>。`

---

## 2. 历史记录方案（Redis + Memory + REST）

## 2.1 广播写入链路（已落地）

- 任何 `broadcast_json(...)` 消息（包括 `chat/system`）都会进入历史缓存
- 内存层：`deque(maxlen=200)` 立刻保留最近窗口
- Redis 层：`LPUSH + LTRIM` 保证重启后可恢复最近 200 条
- Redis 异常不会阻塞实时广播链路

### 2.2 REST 历史接口（已实现）

- `GET /api/chat/history/{room_id}?limit=200`
- 参数：
  - `room_id`：房间标识
  - `limit`：返回条数（默认 200，范围 1~200）
- 返回：
  - `list[RoomHistoryMessage]`（按时间正序）
  - 字段：`type`, `sender?`, `content`, `timestamp`

### 2.3 DB 持久化状态（兼容保留）

- 聊天消息写 DB 逻辑仍保留，可用于长期归档/审计
- 当前“最近消息”接口改为 Redis/内存优先，响应更贴近实时广播内容

---

## 3. 前端 RoomChat 分阶段加载策略（目标方案）

> 目标：提升切房首屏体验，避免“先连 WS 再补历史”导致的跳动感。

推荐且已确认的加载时序：

1. **阶段 A：切房初始化**
   - 清空当前消息列表
   - 状态置为 `switching`
   - 关闭旧 WS 连接（cleanup）

2. **阶段 B：HTTP 拉取历史**
   - 请求：`GET /api/chat/history/{room_id}?limit=200`
   - 将历史记录写入 `messages`（注意前端显示顺序）

3. **阶段 C：建立 WS 增量流**
   - 连接：`/api/ws/{room_id}?token=...`
   - 仅追加新实时消息，不重复灌入历史

4. **阶段 D：UI 进入 online**
   - 切换状态为 `online`
   - 自动滚动到底部

建议补充去重策略：

- 用 `id`（历史）与 `timestamp+sender+content`（实时兜底）联合去重，
  防止切房边界时刻的重复显示。

---

## 4. 纯前端转场特效架构（CRT 断流 / 频段切换）

### 4.1 结构分层

转场特效基于前端状态驱动，不依赖后端：

- 触发源：房间切换点击事件
- 显示层：`RoomChat` 内部覆盖层（局部聊天区）
- 生命周期：
  - 触发：`setChannelState("switching")`
  - 播放：噪点 + 色差 + 文本闪烁
  - 结束：定时后执行路由跳转并自动消失

### 4.2 当前样式要点

- 黑白雪花噪点（SVG data-uri）
- RGB 色差分离（红蓝重影）
- 中央等宽文本提示（如 `[ SIGNALYLOST ]`）
- `pointer-events: none` 防止出现“无形玻璃层”阻塞交互

### 4.3 性能约束

- 动画时长短（当前 600ms）
- 仅在切换瞬间挂载
- 使用 `steps(...)` 与轻量 transform/filter，避免持续高开销

---

## 5. 当前状态与后续建议

### 已完成

- 多房间 WS 隔离（后端）
- 广播消息双写缓存（Memory + Redis）+ 历史查询 API（后端）
- RoomChat 多房间切换与转场特效（前端）
- 基础设施可替换抽象（SQLite/PG、Memory/Redis）

### 建议下一步

1. 在 `RoomChat` 落地“先 HTTP 历史，再 WS 增量”完整链路。  
2. 为历史接口增加 `before_timestamp`/`cursor`，支持分页回溯。  
3. 聊天消息加敏感词/风控拦截（对齐 `content_moderation` 规约）。  
4. 增加 Redis 不可用时的告警与重试策略（观测性补齐）。  

---

*本文件用于冻结当前架构共识，防止上下文漂移。*
