from __future__ import annotations

import logging

from db.base import DatabaseProvider

logger = logging.getLogger("infra.db.postgres")


class PostgresProvider(DatabaseProvider):
    """
    PostgreSQL 适配器占位：
    当前仅预留切换接口，后续接入 asyncpg/SQLAlchemy async engine。
    """

    name = "postgres"

    def __init__(self, *, dsn: str) -> None:
        self.dsn = dsn
        self._connected = False

    async def connect(self) -> None:
        logger.warning(
            "[DB] POSTGRES provider is placeholder now. DSN=%s, falling back to unavailable state.",
            self.dsn,
        )
        self._connected = False

    async def disconnect(self) -> None:
        self._connected = False

    async def healthcheck(self) -> bool:
        return self._connected

    async def get_user_cyber_name(self, *, phone_number: str) -> str | None:
        _ = phone_number
        return None

    async def create_user_profile(self, *, phone_number: str, cyber_name: str) -> bool:
        _ = (phone_number, cyber_name)
        return False

    async def save_chat_message(
        self,
        *,
        room_id: str,
        sender: str,
        content: str,
        timestamp: str,
    ) -> None:
        _ = (room_id, sender, content, timestamp)

    async def list_chat_messages(self, *, room_id: str, limit: int) -> list[dict]:
        _ = (room_id, limit)
        return []

