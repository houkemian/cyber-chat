from __future__ import annotations

import asyncio

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes.announcements import router as announcements_router
from api.routes.auth import router as auth_router
from api.routes.chat import router as chat_router
from cache.manager import CacheManager
from core.settings import AppSettings
from db.manager import DatabaseManager
from services.ai_agent import get_cyber_poet
from utils.ws_manager import ws_manager

# ── 环境变量加载 ─────────────────────────────────────────────
load_dotenv()

app = FastAPI(
    title="赛博树洞 / 2000.exe",
    version="0.1.0",
    description="Y2K 千禧赛博风匿名聊天室后端",
)

settings = AppSettings.from_env()
db_manager = DatabaseManager(settings=settings)
cache_manager = CacheManager(settings=settings)

# ── CORS ────────────────────────────────────────────────────
# 开发阶段放行本地 Vite 前端；生产环境通过 CORS_ORIGINS 环境变量注入
cors_origins = settings.cors_origins or [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    # 开发兜底：允许常见局域网地址访问 Vite（手机调试常用）。
    # 若设置了 CORS_ORIGINS，仍以 allow_origins 精确列表为主。
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 路由挂载 ────────────────────────────────────────────────
app.include_router(auth_router, prefix="/api")
app.include_router(chat_router, prefix="/api")
app.include_router(announcements_router, prefix="/api")


# ── 基础设施生命周期 ─────────────────────────────────────────
@app.on_event("startup")
async def startup_infra() -> None:
    """
    启动时建立基础设施连接。
    当前默认：SQLite + InMemory Cache。
    """
    await db_manager.connect()
    await cache_manager.connect()
    await ws_manager.configure_redis(settings.redis_dsn)
    app.state.db = db_manager
    app.state.cache = cache_manager
    app.state.cyber_poet_task = asyncio.create_task(
        get_cyber_poet().run_forever(),
        name="cyber_poet",
    )


@app.on_event("shutdown")
async def shutdown_infra() -> None:
    """停止时释放基础设施连接。"""
    task = getattr(app.state, "cyber_poet_task", None)
    if task is not None and not task.done():
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
    await ws_manager.close()
    await cache_manager.disconnect()
    await db_manager.disconnect()


# ── 健康探针 ────────────────────────────────────────────────
@app.get("/health")
async def health() -> dict:
    """心跳检测端点，供 DevOps / 负载均衡器使用。"""
    db_ok = await db_manager.healthcheck()
    cache_ok = await cache_manager.healthcheck()
    return {
        "ok": db_ok and cache_ok,
        "db_backend": settings.db_backend,
        "cache_backend": settings.cache_backend,
        "db_ok": db_ok,
        "cache_ok": cache_ok,
    }
