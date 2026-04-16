# ARCHITECTURE_v4.md
# 2000.exe · 架构中枢（索引版 · 2026-04）

> **定位**：全项目「为什么这样设计」的叙事入口与 Phase 路线图；**细粒度技术细节已拆到分卷**，避免单文件膨胀。  
> **快照时间**：2026-04-03 · **仓库**：https://github.com/houkemian/cyber-chat  
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
| `DATABASE_URL` | `postgresql://...@db:5432/...` | ✅ | PostgreSQL DSN（容器内默认连 `db`） |
| `REDIS_URL` | `redis://redis:6379/0` | 建议 | Redis DSN（不可达时降级内存） |
| `POSTGRES_USER` | `cyber_user` | ✅ | PostgreSQL 用户名（供 compose 与 db 容器初始化） |
| `POSTGRES_PASSWORD` | 无 | ✅ | PostgreSQL 密码（必须在 `.env` 显式设置） |
| `POSTGRES_DB` | `cyber_chat` | ✅ | PostgreSQL 数据库名 |
| `SMS_PROVIDER` | `mock` | 建议 | 短信服务提供方：`mock` / `aliyun` |
| `MOBILE_LOGIN_PROVIDER` | `mock` | 建议 | 手机无感登录校验提供方：`mock` / `aliyun` |
| `ALIYUN_ACCESS_KEY_ID` | `""` | 阿里云必填 | 阿里云 AccessKey ID（短信 + 号码认证） |
| `ALIYUN_ACCESS_KEY_SECRET` | `""` | 阿里云必填 | 阿里云 AccessKey Secret |
| `ALIYUN_SMS_SIGN_NAME` | `""` | 阿里云短信必填 | 短信签名 |
| `ALIYUN_SMS_TEMPLATE_CODE` | `""` | 阿里云短信必填 | 短信模板编码（模板变量 `code`） |

---

## 13. 已落地清单（浓缩）

- **Phase-1**：FastAPI 多房间 WS、JWT、四扇区、历史 HTTP 拉取与流式渲染、基础赛博 UI。  
- **Phase-2**：根域名直达部署（Vite + Router + nginx）、同域 `/cyber-api` 反向代理、房间切换、数据残响分界线、`online_count`、登录重连（`loginSeq`）、命令面板移动端、CI/CD。  
- **Phase-3**：三区布局与公告轮播、头像池、成员探测与系统消息分级、行内消息排版、退出与 WS 清理、移动端 Header 与 `100dvh`/safe-area。  
- **Phase-3.5**：命令面板重排、通电闪烁、全屏雷达、`12% / 18% / flex:1` 三区比例。  
- **Phase-3.5+**：CFS、CRT 滤镜、顶栏对齐与 `cyberName` 注入、**GET `/api/ws/rooms/{room_id}/members`**、前端消息列表 **200 条上限**（与后端一致）、A2HS（Manifest + SW + 图标 + 安装引导）。

---

## 14. Phase-4 待建

| 优先级 | 任务 | 关键点 |
|--------|------|--------|
| P0 | 生产安全加固 | 移除万能密码 `0000`，轮换 `JWT_SECRET`，`CORS_ORIGINS` 精确注入 |
| ~~P1~~ | ~~短信验证登录（阿里云）~~ | **已完成**：`SMS_PROVIDER=aliyun` 走阿里云短信发送，验证码校验与 JWT 签发链路已全链路上线 |
| ~~P1~~ | ~~手机无感登录（阿里云）~~ | **已取消**：该能力不再推进，后续从产品与技术路线中移除 |
| ~~P0~~ | ~~PostgreSQL 正式接入~~ | **已实现**：`asyncpg` 连接池 + `user_profiles/chat_messages` 自动建表 |
| ~~P0~~ | ~~公告 API 化~~ | **已实现**：`GET /api/announcements`，数据经 `CacheManager`（内存默认，可切 Redis） |
| ~~P1~~ | ~~成员列表 API 化~~ | **已实现**：`GET /api/ws/rooms/{room_id}/members` |
| P1 | WS 心跳保活 | 客户端 ping / 服务端 pong，防 Nginx 长连接超时 |
| P1 | H5 添加到桌面异常修复 | 当前部分机型/浏览器无法正常触发安装；补齐 HTTPS + Manifest + SW 生效链路校验，增加安装入口兜底（菜单引导/手动添加步骤）与埋点 |
| P1 | AI 气氛组 Agent | `/backend/services/ai_agent.py`，与主鉴权链路隔离 |
| P1 | 分区人格 LLM Agent | `backend/services/llm_agent.py`：`reply`→chat，`action`→system；带记忆折叠、超时/重试/熔断、单房间锁 |
| ~~P1~~ | ~~内容安全拦截~~ | **已实现**：接入 DFA 关键词过滤（`backend/utils/cyber_filter.py` + `backend/sensitive-stop-words`），聊天消息自动脱敏，鉴权请求命中敏感词直接拒绝 |
| P2 | 历史消息分页 | `before_timestamp` / `cursor` |
| P2 | 消息去重 | 切房时历史与 WS 重叠：`timestamp+sender+content` |
| P2 | PWA / 离线缓存 | Service Worker |
| P2 | 天气系统 | 房间内的机器人设定物理位置，可查询天气，根据天气触发消息 |
| P2 | Tool Calls | 在前端引入可扩展的“工具调用”通道（结构化 JSON），允许 Agent 触发 UI/环境动作（不阻塞主链路） |

---

## 15. H5 打包成 APP 所需清单

> 目标：在保留现有 H5 主体的前提下，提供可上架/可安装的移动端 APP 形态。  
> 推荐两条路并行评估：**PWA 安装增强**（轻量）与 **壳工程打包**（Capacitor/TWA/uni-app 壳）。

### 15.1 通用准备（两条路线都需要）

- 稳定的线上 HTTPS 域名（证书有效、全站无 mixed content）。
- 前端生产构建可重复（版本号、构建时间、环境变量区分 dev/staging/prod）。
- 登录态策略与风控策略（token 刷新、设备标识、异常登录告警）。
- 兼容性基线定义（最低 Android/iOS 版本、Chrome/WebView 版本）。
- 监控与埋点（启动失败、白屏、安装入口点击、安装成功率、崩溃率）。

### 15.2 路线 A：PWA（添加到桌面）

- `manifest.webmanifest`：名称、图标（至少 192/512）、`display`、`start_url`、`theme_color`。
- Service Worker：可注册且处于激活态，核心静态资源缓存策略清晰。
- 安装条件校验：HTTPS、生效 manifest、合规 icon、可控 `beforeinstallprompt`。
- iOS 兼容：补充 Safari 手动“添加到主屏幕”引导（iOS 不支持标准安装弹窗）。
- 安装失败兜底：在 UI 提供“如何添加到桌面”分机型说明与重试入口。

### 15.3 路线 B：壳工程打包（真正 APP）

- 壳技术选型：Capacitor（通用 WebView）/ TWA（Android）/ React Native WebView（定制）。
- Android 侧：应用签名、包名、`targetSdkVersion`、权限清单、启动图标与闪屏、渠道包策略。
- iOS 侧：Bundle ID、证书与 Provisioning Profile、ATS 白名单、隐私权限描述（相机/相册/通知等）。
- 原生能力桥接：推送、文件访问、剪贴板、分享、定位等能力按需接入插件。
- 发布准备：隐私政策、用户协议、应用截图、版本说明、审核素材与回滚方案。

### 15.4 当前项目建议优先级

1. 先修复 P1 的 A2HS 异常，拉高移动端“可安装率”。
2. 同步建立壳工程 PoC（优先 Capacitor + Android），验证登录态、WS 长连、消息通知。
3. 根据留存与分发目标决定是否推进双端商店上架。

*重大架构变更请更新本分卷索引，或新增 `ARCHITECTURE_v5.md` 并在此添加链接。*
