from __future__ import annotations

from typing import Any

from core.settings import AppSettings
from db.base import DatabaseProvider
from db.postgres_provider import PostgresProvider
from db.sqlite_provider import SQLiteProvider


class DatabaseManager:
    def __init__(self, *, settings: AppSettings) -> None:
        self.settings = settings
        self.provider = self._build_provider(settings)

    @staticmethod
    def _build_provider(settings: AppSettings) -> DatabaseProvider:
        if settings.db_backend == "sqlite":
            return SQLiteProvider(sqlite_path=settings.sqlite_path)
        if settings.db_backend == "postgres":
            return PostgresProvider(dsn=settings.postgres_dsn)
        raise ValueError(f"Unsupported DB_BACKEND: {settings.db_backend}")

    async def connect(self) -> None:
        await self.provider.connect()

    async def disconnect(self) -> None:
        await self.provider.disconnect()

    async def healthcheck(self) -> bool:
        return await self.provider.healthcheck()

    async def get_user_cyber_name(self, *, phone_number: str) -> str | None:
        return await self.provider.get_user_cyber_name(phone_number=phone_number)

    async def create_user_profile(self, *, phone_number: str, cyber_name: str) -> bool:
        return await self.provider.create_user_profile(
            phone_number=phone_number,
            cyber_name=cyber_name,
        )

    async def update_user_cyber_name(self, *, phone_number: str, cyber_name: str) -> bool:
        return await self.provider.update_user_cyber_name(
            phone_number=phone_number,
            cyber_name=cyber_name,
        )

    async def save_chat_message(
        self,
        *,
        room_id: str,
        sender: str,
        content: str,
        timestamp: str,
    ) -> None:
        await self.provider.save_chat_message(
            room_id=room_id,
            sender=sender,
            content=content,
            timestamp=timestamp,
        )

    async def list_chat_messages(self, *, room_id: str, limit: int) -> list[dict[str, Any]]:
        return await self.provider.list_chat_messages(room_id=room_id, limit=limit)

