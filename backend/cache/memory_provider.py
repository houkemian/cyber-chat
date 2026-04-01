from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from cache.base import CacheProvider


class InMemoryCacheProvider(CacheProvider):
    name = "memory"

    def __init__(self) -> None:
        self._store: dict[str, tuple[Any, datetime | None]] = {}
        self._connected = False

    async def connect(self) -> None:
        self._connected = True

    async def disconnect(self) -> None:
        self._store.clear()
        self._connected = False

    async def healthcheck(self) -> bool:
        return self._connected

    async def get(self, key: str) -> Any | None:
        record = self._store.get(key)
        if record is None:
            return None

        value, expires_at = record
        if expires_at and datetime.now(tz=timezone.utc) > expires_at:
            self._store.pop(key, None)
            return None

        return value

    async def set(self, key: str, value: Any, *, ttl_seconds: int | None = None) -> None:
        expires_at = None
        if ttl_seconds is not None and ttl_seconds > 0:
            expires_at = datetime.now(tz=timezone.utc) + timedelta(seconds=ttl_seconds)
        self._store[key] = (value, expires_at)

    async def delete(self, key: str) -> None:
        self._store.pop(key, None)

