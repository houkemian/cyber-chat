# ARCHITECTURE_v4.md
# 2000.exe · 架构中枢（索引版 · 2026-04）

> **定位**：全项目「为什么这样设计」的叙事入口与 Phase 路线图；**细粒度技术细节已拆到分卷**，避免单文件膨胀。  
> **快照时间**：2026-04-02 · **仓库**：https://github.com/houkemian/cyber-chat  
> **前序文档**：[ARCHITECTURE_v3.md](./ARCHITECTURE_v3.md)

---

## 文档地图（按阅读粒度）

| 文件 | 粒度 | 何时读 |
|------|------|--------|
| [PROJECT_MAP.md](./PROJECT_MAP.md) | **极简（≤50 行）** | 必首次读：目录摘要、技术栈、核心 API |
| [STYLE_GUIDE.md](./STYLE_GUIDE.md) | 样式专卷 | 改 `index.css`、动效、布局、移动端时 |
| [LOGIC_FLOW.md](./LOGIC_FLOW.md) | 逻辑专卷 | 改 WS、房间状态机、历史同步、消息列表时 |
| [SNAPSHOT_MINI.md](./SNAPSHOT_MINI.md) | 轻量快照 | 仅需要 §2 目录 + §7 布局 ASCII + §11 接口表时 |

---

## 0. 世界观 · 系统哲学（继承 v3）

> 这不是一个普通的聊天室。这是一个在千禧年末世数字荒野中燃烧的**赛博树洞**。  
> 每个接入的终端都是匿名的；**USR 流**展示本扇区聊天与数据残响，**本地列表与后端历史 deque 对齐，最多保留最近 200 条**（无消息自毁）。  
> 探测他人，是在黑暗中发射的一道雷达束。

**Phase-3.5 核心变更（相对 Phase-3）**：命令面板重排（探测图标 + 宽输入）、输入通电闪烁、全屏雷达扫描成员、CFS 伪指令（`/whoami`、`/ls`、`/clear`）。

**工作区增量（快照）**：CRT 根壳 `.crt-container`、顶栏与三区对齐变量、成员 **HTTP API**、DiceBear 头像、头像菜单精简等。样式与动画细节一律见 **STYLE_GUIDE.md**；连接与状态机见 **LOGIC_FLOW.md**。

---

## 1. 技术栈总览

见 **[PROJECT_MAP.md](./PROJECT_MAP.md)** 第二节；与 v3 相比**无新增运行时依赖**（仍是 React 18 + Vite + FastAPI + Tailwind + 手写 `index.css`）。

---

## 2. 分卷内容对照（原 v4 章节）

原 `ARCHITECTURE_v4` 长文中的块已迁移如下，避免重复维护：

| 原章节 | 现归属 |
|--------|--------|
| 目录树、API 表 | `PROJECT_MAP.md`、`SNAPSHOT_MINI.md` |
| 后端 WS / 鉴权叙述 | `LOGIC_FLOW.md` §1、§5 |
| 前端 App / RoomChat 状态机、数据流 | `LOGIC_FLOW.md` §2–§4 |
| 命令面板、CRT、雷达、CSS 动画、移动端 | `STYLE_GUIDE.md` |
| 布局 ASCII | `SNAPSHOT_MINI.md` §7 |

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

## 13. 已落地清单（浓缩）

- **Phase-1**：FastAPI 多房间 WS、JWT、四扇区、历史 HTTP 拉取与流式渲染、基础赛博 UI。  
- **Phase-2**：子路径部署（Vite + Router + nginx）、房间切换、数据残响分界线、`online_count`、登录重连（`loginSeq`）、命令面板移动端、CI/CD。  
- **Phase-3**：三区布局与公告轮播、头像池、成员探测与系统消息分级、行内消息排版、退出与 WS 清理、移动端 Header 与 `100dvh`/safe-area。  
- **Phase-3.5**：命令面板重排、通电闪烁、全屏雷达、`12% / 18% / flex:1` 三区比例。  
- **Phase-3.5+**：CFS、CRT 滤镜、顶栏对齐与 `cyberName` 注入、**GET `/api/ws/rooms/{room_id}/members`**、前端消息列表 **200 条上限**（与后端一致）。

---

## 14. Phase-4 待建

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产安全加固 | 移除万能密码 `0000`，轮换 `JWT_SECRET`，`CORS_ORIGINS` 精确注入 |
| P0 | PostgreSQL 正式接入 | 完善 `db/postgres_provider.py`，执行 schema 迁移 |
| ~~P0~~ | ~~公告 API 化~~ | **已实现**：`GET /api/announcements`，数据经 `CacheManager`（内存默认，可切 Redis） |
| ~~P1~~ | ~~成员列表 API 化~~ | **已实现**：`GET /api/ws/rooms/{room_id}/members` |
| P1 | WS 心跳保活 | 客户端 ping / 服务端 pong，防 Nginx 长连接超时 |
| P1 | AI 气氛组 Agent | `/backend/services/ai_agent.py`，与主鉴权链路隔离 |
| P1 | 内容安全拦截 | 填充 `content_moderation`，接入风控或关键词 |
| P2 | 历史消息分页 | `before_timestamp` / `cursor` |
| P2 | 消息去重 | 切房时历史与 WS 重叠：`timestamp+sender+content` |
| P2 | PWA / 离线缓存 | Service Worker |

---

*重大架构变更请更新本分卷索引，或新增 `ARCHITECTURE_v5.md` 并在此添加链接。*
