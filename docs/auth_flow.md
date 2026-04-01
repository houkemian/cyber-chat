# 认证模块架构文档 · Auth Flow

> **项目**：2000.exe — 赛博树洞 / Cyber Dream Space  
> **模块**：用户身份初始化（手机号验证码登录，注册与登录合并）  
> **版本**：MVP v0.1  
> **最后更新**：2026-03-31

---

## 目录

1. [整体架构](#1-整体架构)
2. [目录结构](#2-目录结构)
3. [接口规范](#3-接口规范)
   - [POST /api/auth/send-key](#31-post-apiauthsend-key)
   - [POST /api/auth/verify](#32-post-apiauthverify)
   - [GET /health](#33-get-health)
4. [数据结构（Pydantic Schemas）](#4-数据结构pydantic-schemas)
5. [业务逻辑](#5-业务逻辑)
   - [验证码服务 MockSMSService](#51-验证码服务-mocksmsservice)
   - [身份生成器 generate_cyber_name](#52-身份生成器-generate_cyber_name)
   - [JWT 签发 create_access_token](#53-jwt-签发-create_access_token)
6. [前端状态机](#6-前端状态机)
   - [LoginTerminal 组件状态流](#61-loginterminal-组件状态流)
   - [localStorage 存储约定](#62-localstorage-存储约定)
   - [App 登录态管理](#63-app-登录态管理)
7. [错误码与异常处理](#7-错误码与异常处理)
8. [安全约定与 TODO](#8-安全约定与-todo)
9. [本地开发启动](#9-本地开发启动)

---

## 1. 整体架构

```
用户打开主页（/ 或 /chat）
    │
    ▼
App.tsx（聊天室主页）
    │  点击「神经潜入」按钮
    ▼
LoginTerminal.tsx（全屏弹层，CRT 终端风）
    │
    ├─ Phase: boot      → 打字机动画 "[ SYSTEM BOOT... 2000.exe ]"
    ├─ Phase: idle      → 输入手机号
    │       │ 点击 [请求时空跃迁密匙]
    │       ▼
    │   POST /api/auth/send-key
    │       │ 200 OK
    ├─ Phase: countdown → 60s 倒计时 + 输入 4 位验证码
    │       │ 点击 [执行身份覆写]
    │       ▼
    │   POST /api/auth/verify
    │       │ 200 OK → { token, cyber_name }
    ├─ Phase: decoding  → 2s 乱码流动画
    ├─ Phase: success   → 高亮展示 cyber_name，2s 后回调
    │
    ▼
App 接收 onSuccess(cyberName) 回调
    │ 写入 localStorage（cyber_token, cyber_name）
    │ 关闭弹层，刷新登录态
    ▼
头像区显示像素头像 + 下拉菜单（代号 / 注销）
```

---

## 2. 目录结构

```
cyber_chat/
├── frontend/
│   └── src/
│       ├── App.tsx                   # 聊天室主页，管理登录弹层开关与登录态
│       ├── main.tsx                  # 挂载根组件（始终渲染 App）
│       ├── index.css                 # 全局样式（含 terminal-* / login-modal-* 类）
│       └── pages/
│           └── LoginTerminal.tsx     # CRT 终端风登录组件（含状态机）
│
└── backend/
    ├── main.py                       # FastAPI 入口，CORS，路由挂载
    ├── requirements.txt              # 依赖锁定
    ├── schemas/
    │   └── auth.py                   # Pydantic 请求/响应模型
    ├── utils/
    │   ├── generator.py              # 千禧复古网名生成器
    │   ├── security.py               # JWT 签发工具
    │   └── sms_mock.py               # 模拟短信网关（内存字典）
    └── api/
        └── routes/
            └── auth.py               # 认证路由（send-key / verify）
```

---

## 3. 接口规范

> **Base URL（开发）**：`http://127.0.0.1:8000`  
> **Content-Type**：`application/json`  
> **CORS**：默认放行 `http://localhost:5173`、`http://127.0.0.1:5173`；  
> 生产环境通过环境变量 `CORS_ORIGINS`（逗号分隔）配置。

---

### 3.1 POST /api/auth/send-key

向指定手机号发送 4 位跃迁密匙（MVP 阶段打印到后端控制台）。

**请求体**

| 字段           | 类型   | 必填 | 约束              | 说明             |
|----------------|--------|------|-------------------|------------------|
| `phone_number` | string | ✅   | 长度 6 ~ 32 字符  | 手机号（不校验格式，由业务层决定） |

```json
{
  "phone_number": "13800138000"
}
```

**成功响应** `200 OK`

| 字段      | 类型    | 说明             |
|-----------|---------|------------------|
| `ok`      | boolean | 固定 `true`      |
| `message` | string  | 人类可读提示文本 |

```json
{
  "ok": true,
  "message": "跃迁密匙已发送至终端信道"
}
```

> ⚠️ 密匙本身**不会**出现在响应体中，仅打印到后端控制台（`WARNING` 级别）。

---

### 3.2 POST /api/auth/verify

校验验证码，成功则签发 JWT 并分配千禧网名。  
**注册与登录合并**：phone_number 无论是否首次都走同一逻辑。  
**开发联调特性**：支持万能验证码 `0000`（无需先调用 `send-key`）。

**请求体**

| 字段           | 类型   | 必填 | 约束              | 说明       |
|----------------|--------|------|-------------------|------------|
| `phone_number` | string | ✅   | 长度 6 ~ 32 字符  | 手机号     |
| `sms_code`     | string | ✅   | 长度 4 ~ 8 字符   | 4 位验证码 |

```json
{
  "phone_number": "13800138000",
  "sms_code": "5956"
}
```

**成功响应** `200 OK`

| 字段         | 类型   | 说明                            |
|--------------|--------|---------------------------------|
| `token`      | string | JWT access token（HS256，24h） |
| `cyber_name` | string | 系统随机分配的千禧复古网名       |

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "cyber_name": "往事随风の月光倾城"
}
```

**失败响应** `400 Bad Request`

```json
{
  "detail": "invalid_or_expired_code"
}
```

触发条件（三种，统一返回相同 detail，不暴露内部状态；`sms_code=0000` 时不触发）：
- 从未对该手机号发送过验证码（信道不存在）
- 验证码输入错误
- 验证码已过期（有效期 5 分钟）

---

### 3.3 GET /health

心跳检测，供 DevOps / 负载均衡器使用。

**响应** `200 OK`

```json
{ "ok": true }
```

---

## 4. 数据结构（Pydantic Schemas）

文件：`backend/schemas/auth.py`

```python
class SendKeyRequest(BaseModel):
    phone_number: str = Field(min_length=6, max_length=32)

class VerifyKeyRequest(BaseModel):
    phone_number: str = Field(min_length=6, max_length=32)
    sms_code:     str = Field(min_length=4, max_length=8)

class AuthResponse(BaseModel):
    token:      str   # JWT access token
    cyber_name: str   # 千禧复古网名
```

**JWT Payload 结构**

| 字段           | 类型     | 说明                      |
|----------------|----------|---------------------------|
| `phone_number` | string   | 用户手机号                |
| `cyber_name`   | string   | 分配的千禧网名            |
| `exp`          | datetime | 过期时间（UTC，+24 小时） |

算法：`HS256`  
密钥来源：环境变量 `JWT_SECRET`（开发默认 `dev-secret-change-me-in-prod`）

---

## 5. 业务逻辑

### 5.1 验证码服务 MockSMSService

文件：`backend/utils/sms_mock.py`

**内存存储结构**

```python
_store: dict[str, dict] = {
    "13800138000": {
        "code":       "5956",          # 4 位数字字符串，补零对齐
        "expires_at": datetime(...)    # UTC，有效期 +5 分钟
    }
}
```

**send_code(phone_number)**
1. 生成 `random.randint(0, 9999)` 补零为 4 位字符串
2. 写入 `_store[phone_number]`（覆盖旧记录）
3. `logger.warning(...)` 打印到控制台（本地调试用）

**verify_code(phone_number, sms_code) → bool**
1. 记录不存在 → 返回 `False`
2. 当前时间 > `expires_at` → 删除记录，返回 `False`
3. `record["code"] == sms_code` → 返回比较结果

> **注意**：当前实现不在验证成功后删除记录（验证码可复用直至过期）。  
> 生产环境需在成功后 `del self._store[phone_number]`，实现一次性密匙。
>
> 路由层另有“万能验证码”短路逻辑：`sms_code == "0000"` 直接放行，不进入 `verify_code`。

---

### 5.2 身份生成器 generate_cyber_name

文件：`backend/utils/generator.py`

**词库（28 个词）**

```
轻舞飞扬 / 冷少 / 水晶之恋 / 往事随风 / 颓废の烟 / 伊人泪
寂寞沙洲冷 / 陌上花开 / 夜色温柔 / 风中追风 / 浅唱离歌 / 忧伤旋律
指尖流年 / 孤独患者 / 黯然神伤 / 落樱缤纷 / 月光倾城 / 梦里花落
沉默是金 / 不再回头 / 等你下课 / 坏坏惹人爱 / 心碎1999 / 霓虹心事
午夜电台 / 游荡的鱼 / 碎冰蓝调 / 末日玫瑰
```

**分隔符（6 种）**：`の` `°` `~` `·` `_` `※`

**生成算法**

```
A = random.choice(WORDS)
B = random.choice(WORDS)
if A == B: return A           # 撞词时返回单词
sep = random.choice(SEP)
if sep == "の": return "Aの B"
return "A{sep}B"
```

---

### 5.3 JWT 签发 create_access_token

文件：`backend/utils/security.py`

```python
def create_access_token(*, secret_key, payload, expires_delta=None) -> str
```

| 参数             | 说明                            |
|------------------|---------------------------------|
| `secret_key`     | 签名密钥（来自环境变量）        |
| `payload`        | 要编码的数据字典                |
| `expires_delta`  | 有效期，默认 `timedelta(hours=24)` |

算法：`HS256`（PyJWT 库）

---

## 6. 前端状态机

### 6.1 LoginTerminal 组件状态流

文件：`frontend/src/pages/LoginTerminal.tsx`

```
boot ──(打字完成 +500ms)──► idle
idle ──(POST send-key 成功)──► countdown
countdown ──(POST verify 触发)──► decoding
decoding ──(200 OK +2s)──► success
decoding ──(400 / 网络错误)──► countdown  ← 回退并显示 error
success ──(+2s)──► onSuccess(cyberName) 回调 or location.href='/chat'
```

**Phase 定义**

| Phase       | 描述                              |
|-------------|-----------------------------------|
| `boot`      | 打字机动画，约 1.4s 后自动进入 `idle` |
| `idle`      | 输入手机号，点击发送密匙          |
| `countdown` | 60s 倒计时 + 输入验证码           |
| `decoding`  | 40 行乱码流动画（2s）             |
| `success`   | 展示 cyber_name，2s 后触发跳转/回调 |

**Props**

| Prop        | 类型                          | 说明                                   |
|-------------|-------------------------------|----------------------------------------|
| `onSuccess` | `(cyberName: string) => void` | 弹层模式下登录成功的回调，不传则跳转 `/chat` |

---

### 6.2 localStorage 存储约定

| Key            | 值                   | 写入时机                      | 清除时机         |
|----------------|----------------------|-------------------------------|------------------|
| `cyber_token`  | JWT string           | `POST /verify` 成功后         | 用户点击「注销」 |
| `cyber_name`   | string               | `POST /verify` 成功后         | 用户点击「注销」 |

> **规约（来自 `.cursorrules`）**：前端不存储真实手机号等敏感信息，  
> 仅存储 `cyber_name` 和 `cyber_token`。

---

### 6.3 App 登录态管理

文件：`frontend/src/App.tsx`

**初始化**（`useEffect` 挂载时）

```ts
const token = localStorage.getItem('cyber_token')
const name  = localStorage.getItem('cyber_name')
if (token) { setIsLoggedIn(true); setCyberName(name) }
```

**登录成功回调**

```ts
const handleLoginSuccess = (name: string) => {
  setIsLoggedIn(true)
  setCyberName(name)
  setShowLogin(false)   // 关闭弹层
}
```

**注销**

```ts
const logout = () => {
  localStorage.removeItem('cyber_token')
  localStorage.removeItem('cyber_name')
  setIsLoggedIn(false)
  setCyberName(null)
}
```

**头像生成**

```ts
const avatarUrl = `https://api.dicebear.com/9.x/pixel-art/svg?seed=${encodeURIComponent(cyberName ?? 'midnight')}`
```

---

## 7. 错误码与异常处理

| 场景                       | HTTP 状态码 | `detail` 字段               | 前端表现                      |
|----------------------------|-------------|------------------------------|-------------------------------|
| 验证码错误 / 过期 / 未发送 | `400`       | `invalid_or_expired_code`   | 回退到 countdown，显示红色错误提示 |
| 手机号长度不足（前端校验）  | —           | —                            | 不发请求，直接展示错误文本    |
| 验证码为空（前端校验）      | —           | —                            | 不发请求，直接展示错误文本    |
| 网络 / 服务器异常           | `5xx`       | —                            | 回退到 countdown，展示通用错误提示 |
| send-key 请求失败           | 任意非 2xx  | —                            | 停留在 idle，展示错误提示     |

---

## 8. 安全约定与 TODO

### 当前 MVP 已做

- [x] JWT HS256 签名，24h 有效期
- [x] Pydantic 字段长度校验
- [x] 验证码 5 分钟过期自动销毁
- [x] 三种失败场景统一 400，不暴露内部状态
- [x] 开发联调万能验证码 `0000`（路由层短路）
- [x] `content_moderation` 依赖占位（每个路由均已挂载 `Depends`）
- [x] 前端不存储手机号等敏感字段

### 生产环境必须完成

- [ ] 替换 `MockSMSService` 为真实短信 SDK（阿里云 / 腾讯云）
- [ ] 验证码验证成功后删除记录（一次性密匙）
- [ ] 接入真实手机号格式校验（正则或第三方库）
- [ ] `JWT_SECRET` 写入服务器环境变量，禁止使用默认值
- [ ] 接口频率限制（同一手机号 60s 内只能发一次验证码）
- [ ] `content_moderation` 接入实际风控逻辑
- [ ] HTTPS 部署（防止 JWT 在传输中泄露）
- [ ] Token 刷新机制 / 黑名单机制

---

## 9. 本地开发启动

```bash
# 后端
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 127.0.0.1 --port 8000

# 前端（另开终端）
cd frontend
npm install
npm run dev
```

**测试认证流程**

```bash
# 1. 发送验证码（看后端终端 WARNING 日志拿到 4 位码）
curl -X POST http://127.0.0.1:8000/api/auth/send-key \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "13800138000"}'

# 2. 校验并登录（替换 XXXX 为控制台打印的验证码）
curl -X POST http://127.0.0.1:8000/api/auth/verify \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "13800138000", "sms_code": "XXXX"}'

# 3. 或使用万能验证码（开发联调）
curl -X POST http://127.0.0.1:8000/api/auth/verify \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "13800138000", "sms_code": "0000"}'
```

或直接访问 `http://localhost:5173`，点击「**神经潜入**」按钮触发弹层登录。

---

*文档生成自代码仓库，与实现保持严格同步。*
