# CONFIGURATION（统一配置清单）

> 目标：集中记录项目配置项与默认值。  
> 后端统一入口：`backend/core/settings.py`  
> 前端配置入口：`frontend/src/config/api.ts`、`frontend/src/config/chat.ts`

---

## 1) 后端环境变量（.env）

### 基础设施


| 变量名             | 默认值                                                        | 说明                          |
| --------------- | ---------------------------------------------------------- | --------------------------- |
| `DB_BACKEND`    | `sqlite`                                                   | 数据库后端：`sqlite` / `postgres` |
| `CACHE_BACKEND` | `memory`                                                   | 缓存后端：`memory` / `redis`     |
| `SQLITE_PATH`   | `./data/cyber_chat.db`                                     | SQLite 文件路径                 |
| `POSTGRES_DSN`  | `postgresql://postgres:postgres@127.0.0.1:5432/cyber_chat` | PostgreSQL 连接串              |
| `REDIS_DSN`     | `redis://127.0.0.1:6379/0`                                 | Redis 连接串（历史缓存）             |


### 安全与跨域


| 变量名            | 默认值                            | 说明                    |
| -------------- | ------------------------------ | --------------------- |
| `JWT_SECRET`   | `dev-secret-change-me-in-prod` | JWT 签名密钥（生产必须替换）      |
| `CORS_ORIGINS` | 空                              | 逗号分隔白名单。为空时使用本地开发默认值。 |


### CyberPoet（赛博诗人）


| 变量名                               | 默认值    | 说明                               |
| --------------------------------- | ------ | -------------------------------- |
| `CYBER_POET_ENABLED`              | `1`    | 是否启用赛博诗人后台任务；`0/false/no/off` 关闭 |
| `CYBER_POET_INTERVAL_MIN_MINUTES` | `20`   | 广播最小间隔（分钟）                       |
| `CYBER_POET_INTERVAL_MAX_MINUTES` | `30`   | 广播最大间隔（分钟）                       |
| `CYBER_POET_INTERVAL_MIN_SEC`     | `1200` | 秒级覆盖（兼容项，优先于分钟项）                 |
| `CYBER_POET_INTERVAL_MAX_SEC`     | `1800` | 秒级覆盖（兼容项，优先于分钟项）                 |
| `CYBER_POET_MAX_MESSAGES_PER_SEC` | `2`    | 多房间广播时全局发送速率上限                   |


### Room LLM Agent（分区人格 AI）


| 变量名                             | 默认值   | 说明                      |
| ------------------------------- | ----- | ----------------------- |
| `LLM_AGENT_TRIGGER_PROBABILITY` | `0.3` | 非 `@AI` 触发时的随机触发概率（0~1） |

#### DeepSeek（OpenAI SDK 兼容）

| 变量名 | 默认值 | 说明 |
|---|---|---|
| `DEEPSEEK_API_KEY` | 空 | DeepSeek API Key（建议放在 `backend/.env` 或 Docker `env_file`） |
| `DEEPSEEK_MODEL` | `deepseek-chat` | 生成 `{"reply","action"}` 使用的模型名 |
| `DEEPSEEK_SUMMARY_MODEL` | 同 `DEEPSEEK_MODEL` | 记忆折叠摘要使用的模型名 |

#### LLM 韧性（超时 / 重试 / 熔断）

| 变量名 | 默认值 | 说明 |
|---|---:|---|
| `LLM_AGENT_GENERATE_TIMEOUT_SEC` | `12` | 生成阶段请求超时（秒） |
| `LLM_AGENT_SUMMARIZE_TIMEOUT_SEC` | `10` | 折叠摘要请求超时（秒） |
| `LLM_AGENT_GENERATE_RETRY_MAX` | `2` | 生成阶段最大重试次数（不含首次） |
| `LLM_AGENT_SUMMARIZE_RETRY_MAX` | `1` | 折叠摘要最大重试次数（不含首次） |
| `LLM_AGENT_CIRCUIT_BREAKER_THRESHOLD` | `3` | 连续失败阈值，达到后打开熔断 |
| `LLM_AGENT_CIRCUIT_BREAKER_COOLDOWN_SEC` | `30` | 熔断冷却时间（秒） |


---

## 2) 前端配置

### API 网关（`frontend/src/config/api.ts`）


| 配置项                | 默认值                            | 说明               |
| ------------------ | ------------------------------ | ---------------- |
| `HTTP_BASE_URL`    | localhost:8001 / 线上网关          | 根据 hostname 自动切换 |
| `WS_BASE_URL`      | ws://localhost:8001 / wss 线上网关 | 根据 hostname 自动切换 |
| `API_AUTH_URL`     | `${HTTP_BASE_URL}/api/auth`    | 认证接口前缀           |
| `CHAT_WS_BASE_URL` | `${WS_BASE_URL}/api/ws`        | 聊天 WS 前缀         |


### 聊天交互（`frontend/src/config/chat.ts`）


| 配置项                                 | 默认值    | 说明          |
| ----------------------------------- | ------ | ----------- |
| `CHAT_RATE_LIMIT.maxSendsPerSecond` | `2`    | 每用户每秒最多发送条数 |
| `CHAT_RATE_LIMIT.windowMs`          | `1000` | 限流窗口毫秒数     |


---

## 3) 使用建议

- 生产环境必须设置：`JWT_SECRET`、`CORS_ORIGINS`。
- 调试 AI 触发可设置：`LLM_AGENT_TRIGGER_PROBABILITY=1`。
- 若仅希望按分钟控制诗人频率，保持 `CYBER_POET_INTERVAL_*_SEC` 未设置即可。
- Docker 部署建议：在 `docker-compose.yml` 中为后端使用 `env_file: ./backend/.env`，避免根目录 `.env` 与容器变量替换混用导致的“读错配置”。

