from __future__ import annotations

from cache.base import CacheProvider
from cache.memory_provider import InMemoryCacheProvider
from cache.redis_provider import RedisCacheProvider
from core.settings import AppSettings


class CacheManager:
    def __init__(self, *, settings: AppSettings) -> None:
        self.settings = settings
        self.provider = self._build_provider(settings)

    @staticmethod
    def _build_provider(settings: AppSettings) -> CacheProvider:
        if settings.cache_backend == "memory":
            return InMemoryCacheProvider()
        if settings.cache_backend == "redis":
            return RedisCacheProvider(dsn=settings.redis_dsn)
        raise ValueError(f"Unsupported CACHE_BACKEND: {settings.cache_backend}")

    async def connect(self) -> None:
        await self.provider.connect()

    async def disconnect(self) -> None:
        await self.provider.disconnect()

    async def healthcheck(self) -> bool:
        return await self.provider.healthcheck()

