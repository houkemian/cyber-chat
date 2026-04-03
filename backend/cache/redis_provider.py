from __future__ import annotations

import json
from typing import Any

import redis.asyncio as redis
from cache.base import CacheProvider


class RedisCacheProvider(CacheProvider):
    name = "redis"

    def __init__(self, *, dsn: str) -> None:
        self.dsn = dsn
        self._client: redis.Redis | None = None

    async def connect(self) -> None:
        self._client = redis.from_url(self.dsn, encoding="utf-8", decode_responses=True)
        await self._client.ping()

    async def disconnect(self) -> None:
        if self._client is None:
            return
        await self._client.aclose()
        self._client = None

    async def healthcheck(self) -> bool:
        if self._client is None:
            return False
        await self._client.ping()
        return True

    async def get(self, key: str) -> Any | None:
        if self._client is None:
            return None
        raw = await self._client.get(key)
        if raw is None:
            return None
        try:
            return json.loads(raw)
        except Exception:
            return raw

    async def set(self, key: str, value: Any, *, ttl_seconds: int | None = None) -> None:
        if self._client is None:
            return
        serialized = json.dumps(value, ensure_ascii=False)
        if ttl_seconds is not None and ttl_seconds > 0:
            await self._client.set(key, serialized, ex=ttl_seconds)
            return
        await self._client.set(key, serialized)

    async def delete(self, key: str) -> None:
        if self._client is None:
            return
        await self._client.delete(key)

