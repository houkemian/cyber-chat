# PROJECT_MAP

> **必读地图**：目录骨架、技术栈、核心 HTTP/WS API。逻辑与样式见 `LOGIC_FLOW.md`、`STYLE_GUIDE.md`。

## 目录树（摘要）

```
cyber_chat/
├── backend/          # FastAPI · main.py · models.py
│   ├── api/routes/   # auth · chat（WS+history+members）· announcements
│   ├── services/     # announcements_cache 等
│   ├── utils/        # ws_manager.py · security.py · generator.py
│   ├── db/ · cache/  # SQLite 默认 · 内存缓存
│   └── data/cyber_chat.db
├── frontend/
│   └── src/
│       ├── App.tsx · main.tsx · index.css
│       ├── pages/LoginTerminal.tsx · RoomChat.tsx
│       └── config/api.ts
├── docs/             # 架构分卷 + ARCHITECTURE_v*.md
├── docker-compose.yml
└── .github/workflows/deploy.yml
```

## 技术栈与版本

| 层级 | 技术 |
|------|------|
| 前端 | React 18 + TypeScript + Vite（`base: '/cyber-chat/'`） |
| 路由 | React Router v6，`basename="/cyber-chat"` |
| 样式 | Tailwind + `frontend/src/index.css`（手写 Y2K，体量约 2900 行） |
| 后端 | FastAPI · WebSocket · SQLite（默认） |
| 容器 | Docker Compose + `nginx:alpine` |
| CI | GitHub Actions（SCP + SSH 重启 Compose） |

## 核心 API

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/auth/send-key` | 下发验证码（开发：控制台） |
| `POST` | `/api/auth/verify` | 校验 → JWT + `cyber_name` |
| `WS` | `/api/ws/{room_id}?token=` | 实时聊天；广播含 `online_count` |
| `GET` | `/api/ws/rooms/{room_id}/members` | 在线成员（去重）+ `online_count` |
| `GET` | `/api/chat/history/{room_id}?limit=200` | 房间最近 200 条 chat |
| `GET` | `/api/announcements` | 公告列表 `{ items: [{ id, content }] }`（缓存：内存 / Redis） |
| `GET` | `/health` | 健康检查 |
