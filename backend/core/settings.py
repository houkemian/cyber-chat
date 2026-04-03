from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


@dataclass(slots=True)
class AppSettings:
    """
    基础设施配置中心：
    - DB_BACKEND: sqlite | postgres
    - CACHE_BACKEND: memory | redis
    """

    db_backend: str = "postgres"
    cache_backend: str = "redis"
    sqlite_path: str = "./data/cyber_chat.db"
    postgres_dsn: str = "postgresql://postgres:postgres@127.0.0.1:5432/cyber_chat"
    redis_dsn: str = "redis://127.0.0.1:6379/0"
    jwt_secret: str = "dev-secret-change-me-in-prod"
    cors_origins: list[str] | None = None

    cyber_poet_enabled: bool = True
    cyber_poet_interval_min_sec: float = 20.0 * 60.0
    cyber_poet_interval_max_sec: float = 30.0 * 60.0
    cyber_poet_max_messages_per_sec: int = 2

    llm_agent_trigger_probability: float = 0.3

    @classmethod
    def from_env(cls) -> "AppSettings":
        raw_cors_origins = os.getenv("CORS_ORIGINS", "")
        cors_origins = [o.strip() for o in raw_cors_origins.split(",") if o.strip()]

        min_minutes = float(os.getenv("CYBER_POET_INTERVAL_MIN_MINUTES", "20"))
        max_minutes = float(os.getenv("CYBER_POET_INTERVAL_MAX_MINUTES", "30"))
        min_seconds = float(
            os.getenv("CYBER_POET_INTERVAL_MIN_SEC", str(min_minutes * 60.0)).strip()
        )
        max_seconds = float(
            os.getenv("CYBER_POET_INTERVAL_MAX_SEC", str(max_minutes * 60.0)).strip()
        )
        if min_seconds > max_seconds:
            min_seconds, max_seconds = max_seconds, min_seconds

        trigger_probability = os.getenv("LLM_AGENT_TRIGGER_PROBABILITY", "0.3").strip()
        try:
            parsed_probability = float(trigger_probability)
        except ValueError:
            parsed_probability = 0.3

        postgres_dsn = os.getenv("POSTGRES_DSN", "").strip() or os.getenv("DATABASE_URL", "").strip()
        if not postgres_dsn:
            postgres_dsn = "postgresql://postgres:postgres@127.0.0.1:5432/cyber_chat"

        redis_dsn = os.getenv("REDIS_DSN", "").strip() or os.getenv("REDIS_URL", "").strip()
        if not redis_dsn:
            redis_dsn = "redis://127.0.0.1:6379/0"

        db_backend = os.getenv("DB_BACKEND", "").strip().lower()
        if not db_backend:
            db_backend = "postgres" if os.getenv("DATABASE_URL", "").strip() else "sqlite"

        cache_backend = os.getenv("CACHE_BACKEND", "").strip().lower()
        if not cache_backend:
            cache_backend = "redis" if os.getenv("REDIS_URL", "").strip() else "memory"

        return cls(
            db_backend=db_backend,
            cache_backend=cache_backend,
            sqlite_path=os.getenv("SQLITE_PATH", "./data/cyber_chat.db").strip(),
            postgres_dsn=postgres_dsn,
            redis_dsn=redis_dsn,
            jwt_secret=os.getenv("JWT_SECRET", "dev-secret-change-me-in-prod").strip(),
            cors_origins=cors_origins or None,
            cyber_poet_enabled=os.getenv("CYBER_POET_ENABLED", "1").strip().lower()
            not in ("0", "false", "no", "off"),
            cyber_poet_interval_min_sec=min_seconds,
            cyber_poet_interval_max_sec=max_seconds,
            cyber_poet_max_messages_per_sec=max(
                1,
                int(os.getenv("CYBER_POET_MAX_MESSAGES_PER_SEC", "2").strip()),
            ),
            llm_agent_trigger_probability=max(0.0, min(parsed_probability, 1.0)),
        )


@lru_cache(maxsize=1)
def get_settings() -> AppSettings:
    """全局配置单例（进程级）。"""
    return AppSettings.from_env()
