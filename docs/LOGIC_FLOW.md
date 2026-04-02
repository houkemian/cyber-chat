# LOGIC_FLOW（逻辑专卷）

> **何时阅读**：改 WebSocket、房间切换、历史同步、消息列表或鉴权时打开。  
> 代码锚点：`backend/utils/ws_manager.py`、`api/routes/chat.py`、`frontend/src/pages/RoomChat.tsx`、`App.tsx`。

---

## 1. 后端：连接与广播

**`ConnectionManager`（单例 `ws_manager`）**

- `rooms[room_id]`：该扇区在线 `WebSocket` 列表。
- `histories[room_id]`：`deque(maxlen=200)`，仅 **chat** 类型入队。
- `_ws_cyber_names[id(ws)] → cyber_name`：成员 API 与去重人数。

**关键方法**

- `connect(ws, room, cyber_name)`：accept → 入池 → 登记 name。
- `disconnect(ws, room)`：出池 → 清 name → 房间空则删键。
- `broadcast_json(payload, room)`：向房间内连接发送 JSON；失败连接剔除；**chat** 同步写入 `histories`。
- `get_room_history(room, limit)`：优先 Redis，否则内存 deque。
- `get_room_members(room)`：异步加锁，按连接顺序去重后的 `cyber_name[]`。

**`chat.py` 路由**

- **WS** `/api/ws/{room_id}`：鉴权 token（Query `token` / `Authorization` / `X-Token`），无效则 `1008`。
- 接入：`connect` → 广播系统消息 `[系统]: 终端 <name> 已接入扇区 <room>。`（前端 `WS_JOIN_RE`）。
- 循环：`receive_text` → 审核占位 → 广播 `{type, sender, content, timestamp}` → 异步写库（失败不阻断）。
- 断开：`disconnect` → 广播 `终端 <name> 已断开扇区 <room>`（前端 `WS_LEAVE_RE`）。
- 异常兜底：对“底层已断链但未抛 `WebSocketDisconnect`”场景做 `RuntimeError` 归一化处理，避免 ASGI 异常导致前端 `1006` 反复重连。
- **HTTP** `GET /api/ws/rooms/{room_id}/members` → `{ members, online_count }`。

**系统消息格式**与 `RoomChat.tsx` 中正则强耦合；成员展示以 **GET members** 为权威，WS 仅增量与 reconcile。

---

## 1.5 后端：LLM Agent（Phase-4）

**`backend/services/llm_agent.py`**

- 房间人格：`ROOM_PERSONALITIES[room_id]`（bot_name + system_prompt）。
- 触发：`@AI` 强制触发，或 `LLM_AGENT_TRIGGER_PROBABILITY` 概率触发。
- 输出协议：模型返回 JSON：`{"reply":"...","action":"..."}`。
- 分路广播：
  - `reply` → `type: "chat"`（进入 `USR://STREAM`）
  - `action` → `type: "system"`（`[系统]：...`，进入 `SYS://FEED`）

**MemoryManager（上下文控膨胀）**

- Level 1 噪声过滤：去除 `system`，去除长度 `<2` 且不含 `@` 的消息。
- Level 2 折叠：有效消息超过 15 条时摘要压缩为 `room_summaries[room_id]`。
- 组装模型上下文顺序：
  1) System Prompt  
  2) Memory Block（远古记忆）  
  3) Recent Context（过滤后近 3-5 条）

**韧性策略**

- 请求超时：`asyncio.wait_for`
- 重试：生成/摘要分别独立重试
- 熔断：生成/摘要分别计数与冷却窗口
- 并发：单房间 `asyncio.Lock`，避免并发重复折叠/重复生成

---

## 2. 前端：`App.tsx` 与重连

| 状态/Ref | 作用 |
|----------|------|
| `loginSeq` | 登录/退出时 `+1`，作为 `RoomChat` 的 `key`/`deps`，**强制**关闭旧 WS、重跑拉历史与连接。 |
| `cyberName` | 展示与注入 `RoomChat`（CFS `/whoami` 等）。 |
| `chatHeight` | `calc(100dvh/100vh - reserved)`，reserved 来自 header 实测高度 + padding + gap。 |

**重连路径**：退出登录 → 清 `localStorage` → `loginSeq++` → `RoomChat` effect 见无 token → `offline`；重新登录 → `loginSeq++` → 新 token → 全量重连。

---

## 3. 前端：`RoomChat.tsx` 状态机

**`channelState`**：`switching` | `online` | `offline`

**`messages`**

- `useMemo` → `systemMessages`（`SYS://FEED`）与 `userMessages`（`USR://STREAM`）。
- **本地条数上限**：`MAX_ROOM_MESSAGES = 200`（与后端 deque、历史 `limit` 对齐）；`messages.length > 200` 时 `slice(-200)`，**无**超时自毁。

**`memberList`**

1. 历史同步阶段：扫描历史里 system 消息的 `WS_JOIN_RE` / `WS_LEAVE_RE` 顺序模拟进退。
2. 实时：WS `onmessage` 增量更新；若与 `online_count` 不一致则 `GET .../members` reconcile。
3. 打开雷达：`showMembers=true` 时优先拉 **members API**。

**Refs**

- `wsRef` / `wsSeqRef`：防旧连接回调污染（序号比对）。
- `systemListRef` / `userListRef`：滚底。
- `historySyncTimerRef`：历史 50ms 批量渲染。
- `switchNavTimerRef`：切房动画后 `navigate`。
- `sendTimestampsRef`：发送限流窗口（每用户每秒最多 2 条）。

**流程（有 token）**

1. `setMessages([])`，`syncHistoryThenConnect`：`GET /api/chat/history/{room_id}?limit=200`（带 timeout）。
2. 流式 `setInterval` 批量 `append` 历史；结束后 `openRealtimeLink` → `WebSocket`。
3. `onmessage`：解析 JSON → 追加 `chat` / `system`；system 可带 `online_count` 更新人数与成员启发式。
4. 发送：`handleSend` → CFS 指令本地处理；否则 `ws.send` 文本。

**连接可靠性（Phase-4）**

- WS 握手 watchdog：连接长时间 `CONNECTING` 会主动 close 并触发重试。
- 切房重连：失败后短延迟重试若干次，超限给系统提示（含 close code）。
- 历史同步失败：显示系统提示并继续尝试实时链路，避免“静默卡住”。

**切扇区**：关 WS → `chaosFx` → `navigate(/chat/:id)`，`roomId` 变化触发上述 effect 重新跑。

---

## 4. 数据流（简图）

```
加载房间
  useEffect([roomId, loginSeq])
    → GET /api/chat/history/{room_id}?limit=200
    → 流式写入 messages；扫描历史 system 初始化 memberList
    → WS /api/ws/{room_id}?token=
    → 广播「已接入」→ channelState online

实时消息
  ws 收 chat → append messages；列表 >200 则截断末尾 200 条

发送
  ws.send(text) → 广播 chat（含自己）

探测
  setShowMembers(true) → GET .../members → RadarScan

登出
  loginSeq++ → token 清空 → ws 关闭 → offline
```

---

## 5. 认证（摘要）

- `POST /api/auth/send-key`、`POST /api/auth/verify` → JWT（HS256，默认 24h）+ `cyber_name`。
- 生产需替换默认 `JWT_SECRET`、收紧 CORS；开发万能码等事项见 `ARCHITECTURE_v4.md` Phase-4。
