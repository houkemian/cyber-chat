from __future__ import annotations

import logging
from typing import Any

from cache.base import CacheProvider

logger = logging.getLogger("infra.cache.redis")


class RedisCacheProvider(CacheProvider):
    """
    Redis 适配器占位：
    当前预留切换入口，后续可接入 redis.asyncio。
    """

    name = "redis"

    def __init__(self, *, dsn: str) -> None:
        self.dsn = dsn
        self._connected = False

    async def connect(self) -> None:
        logger.warning(
            "[CACHE] REDIS provider is placeholder now. DSN=%s, falling back to unavailable state.",
            self.dsn,
        )
        self._connected = False

    async def disconnect(self) -> None:
        self._connected = False

    async def healthcheck(self) -> bool:
        return self._connected

    async def get(self, key: str) -> Any | None:
        return None

    async def set(self, key: str, value: Any, *, ttl_seconds: int | None = None) -> None:
        _ = (key, value, ttl_seconds)

    async def delete(self, key: str) -> None:
        _ = key

