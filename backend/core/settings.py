from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(slots=True)
class AppSettings:
    """
    基础设施配置中心：
    - DB_BACKEND: sqlite | postgres
    - CACHE_BACKEND: memory | redis
    """

    db_backend: str = "sqlite"
    cache_backend: str = "memory"
    sqlite_path: str = "./data/cyber_chat.db"
    postgres_dsn: str = "postgresql://postgres:postgres@127.0.0.1:5432/cyber_chat"
    redis_dsn: str = "redis://127.0.0.1:6379/0"

    @classmethod
    def from_env(cls) -> "AppSettings":
        return cls(
            db_backend=os.getenv("DB_BACKEND", "sqlite").strip().lower(),
            cache_backend=os.getenv("CACHE_BACKEND", "memory").strip().lower(),
            sqlite_path=os.getenv("SQLITE_PATH", "./data/cyber_chat.db").strip(),
            postgres_dsn=os.getenv(
                "POSTGRES_DSN",
                "postgresql://postgres:postgres@127.0.0.1:5432/cyber_chat",
            ).strip(),
            redis_dsn=os.getenv("REDIS_DSN", "redis://127.0.0.1:6379/0").strip(),
        )

