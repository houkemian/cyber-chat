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
| ~~P1~~ | ~~H5 添加到桌面异常修复~~ | **已完成**：安装入口迁移至头像菜单，支持标准安装弹窗与 iOS 手动添加兜底引导，并补齐可用性提示 |
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

---

## 16. 头像下拉菜单 · 功能建议

> **范围**：顶栏右侧头像触发的下拉/弹出菜单（Web 与 Flutter 客户端应对齐叙事；实现细节见各端 `App` / `CyberHeaderBar`）。  
> **原则**：匿名树洞语境下，菜单宜短、可预期；重操作走二次确认，敏感能力不与「实时聊天主链路」抢线程。

### 16.1 现状（快照）

| 端 | 已具备 | 备注 |
|----|--------|------|
| Web | 身份文案（Uplink Key / `cyberName`）、退出 | 历史曾含「添加到主屏幕 / 扫码」等安装引导，以 PWA 与 Manifest 为准迭代 |
| Flutter | 身份展示、`终止当前进程`（退出登录） | 已去掉「部署到主屏幕」「下载移动端矩阵」；原生安装与分发走应用商店 / 侧载，不在此菜单重复 |

### 16.2 建议项（可按 Phase 取舍）

**体验与身份（P1–P2）**

- **头像与身份**：在菜单内提供「更换像素身份」入口，直接联动 **头像池**（DiceBear seed / 本地索引），改完即写回 `SessionStore` / 前端等价物并刷新顶栏；可选展示当前 seed 的短摘要（非明文手机号）。
- **昵称 / 赛博呼号**：若产品允许修改 `cyberName`，菜单进入轻量表单 + 后端校验（长度、敏感词与同名校验），与现有 JWT 更新策略一致；否则仅展示只读 + 「为何不可改」一句说明。
- **会话与本地数据**：提供「清空本机聊天记录缓存」「清空草稿」等仅影响本地的项（Flutter `SharedPreferences` / Web `localStorage` 范围需写清），避免与服务器历史删除混淆。
- **通知（Flutter）**：系统通知权限说明与跳转（若后续上推送）；Web 则对应 Notification API 与权限状态一句话。

**合规与账号（P2）**

- **退出以外的账号动作**：注销账号、导出个人数据、隐私政策链接——若上线需配套后端与法务文案；菜单入口宜靠后，且与「退出会话」视觉区分（例如分组线 + 次级色）。

**世界观与可发现性（P3）**

- **快捷跳转**：雷达探测、当前扇区信息、快捷键说明（`/whoami` 等 CFS）——与命令面板能力重复时，菜单只做「入口聚合」+ 一句 lore，避免两套逻辑。
- **关于**：版本号、构建号、`2000.exe` 文案、仓库或反馈链接（只读），便于排障与用户自发传播。

**不建议塞进头像菜单的**

- 与安装/分发强相关且各端差异极大的能力（已迁出独立渠道或商店说明）。
- 重型设置（全站主题、多语言大表单）——更适合独立「设置」页，头像菜单仅保留 **1 键到达** 的跳转。

🧬 一、 伪装与身份重构 (Identity & Camouflage)
这是匿名应用最核心的玩法。

生成随机马赛克/噪点头像 (Noise Generative Avatar)：

功能：不需要用户上传图片。根据用户的 UUID（设备指纹）生成一张独一无二的 16-bit 像素头像、条形码或者哈希噪点图。

交互：点击头像会伴随“滋滋”的电流声，并发生一次短暂的视觉故障（Glitch）。

重置身份 (Regenerate Alias)：

功能：既然是临时分配的 cyber_name（比如：流浪者_9527），提供一个按钮可以随时“销毁当前身份”并重新抽取一个新代号。

文案：不叫“修改昵称”，叫“伪造新身份 (Forge New Identity)”。

🎛️ 二、 视觉与听觉调优 (Terminal Preferences)
利用 Flutter 强大的渲染能力和原生权限，做一些 H5 做不到的极致体验。

CRT 显像管老化程度 (CRT Scanline Intensity)：

功能：一个粗糙的滑块。滑到最左边是高清的，滑到最右边屏幕布满扫描线、闪烁加剧、四角出现老电视的暗角（Vignette）。

物理震动引擎 (Haptic Engine)：

功能：开关。开启后，不仅打字有震动，别人发来带“@”你的消息时，手机会执行一个短促而暴力的马达震动（模拟寻呼机）。

拨号音效 (Dial-up Audio)：

功能：开关。进入房间时是否播放极其刺耳的 56k 调制解调器拨号连接音。

📡 三、 赛博状态监控 (Cyber Status)
把普通的“关于我们”和“账号信息”包装成监控面板。

神经接驳时长 (Uptime)：

功能：显示距离第一次打开应用或者本次连接后端的总时长（例如：UPTIME: 04:12:33）。

当前节点延迟 (Ping / Latency)：

功能：实时显示与后端的 WebSocket 延迟数据（例如：[OK] HOST_REACHABLE: 42ms），如果延迟高，数字变红并闪烁。

💥 四、 物理断连 (Eject / Danger Zone)
紧急脱机 (Eject Connection)：

功能：替代普通的“退出登录”。点击后，WebSocket 瞬间切断，屏幕伴随一个旧电视关机的“向中心收缩”的动画。

自毁程序 (Self-Destruct / Clear Cache)：

功能：清空本地所有的聊天缓存和设备指纹，彻底消失在赛博空间。
*重大架构变更请更新本分卷索引，或新增 `ARCHITECTURE_v5.md` 并在此添加链接。*
