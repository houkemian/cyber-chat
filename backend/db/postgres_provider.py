from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import asyncpg

from db.base import DatabaseProvider


class PostgresProvider(DatabaseProvider):
    name = "postgres"

    def __init__(self, *, dsn: str) -> None:
        self.dsn = dsn
        self._pool: asyncpg.Pool | None = None

    async def connect(self) -> None:
        self._pool = await asyncpg.create_pool(self.dsn, min_size=1, max_size=10)
        async with self._pool.acquire() as conn:
            await conn.execute(
                """
                CREATE TABLE IF NOT EXISTS user_profiles (
                    id BIGSERIAL PRIMARY KEY,
                    phone_number TEXT NOT NULL UNIQUE,
                    cyber_name TEXT NOT NULL,
                    identity_forge_count INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                )
                """
            )
            await conn.execute(
                """
                ALTER TABLE user_profiles
                ADD COLUMN IF NOT EXISTS identity_forge_count INTEGER NOT NULL DEFAULT 0
                """
            )
            await conn.execute(
                """
                CREATE TABLE IF NOT EXISTS chat_messages (
                    id BIGSERIAL PRIMARY KEY,
                    room_id TEXT NOT NULL,
                    sender TEXT NOT NULL,
                    content TEXT NOT NULL,
                    timestamp TEXT NOT NULL
                )
                """
            )

    async def disconnect(self) -> None:
        if self._pool is None:
            return
        await self._pool.close()
        self._pool = None

    async def healthcheck(self) -> bool:
        if self._pool is None:
            return False
        async with self._pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return True

    async def get_user_cyber_name(self, *, phone_number: str) -> str | None:
        if self._pool is None:
            return None
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT cyber_name FROM user_profiles WHERE phone_number = $1 LIMIT 1",
                phone_number,
            )
        if row is None:
            return None
        return str(row["cyber_name"])

    async def create_user_profile(self, *, phone_number: str, cyber_name: str) -> bool:
        if self._pool is None:
            return False
        async with self._pool.acquire() as conn:
            result = await conn.execute(
                """
                INSERT INTO user_profiles (phone_number, cyber_name, created_at)
                VALUES ($1, $2, $3)
                ON CONFLICT (phone_number) DO NOTHING
                """,
                phone_number,
                cyber_name,
                datetime.now(tz=timezone.utc).isoformat(),
            )
        return result.endswith("1")

    async def update_user_cyber_name(self, *, phone_number: str, cyber_name: str) -> bool:
        if self._pool is None:
            return False
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                UPDATE user_profiles SET cyber_name = $1
                WHERE phone_number = $2
                RETURNING phone_number
                """,
                cyber_name,
                phone_number,
            )
        return row is not None

    async def increment_identity_forge_count(
        self,
        *,
        phone_number: str,
        max_attempts: int,
    ) -> int | None:
        if self._pool is None:
            return None
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                UPDATE user_profiles
                SET identity_forge_count = identity_forge_count + 1
                WHERE phone_number = $1 AND identity_forge_count < $2
                RETURNING identity_forge_count
                """,
                phone_number,
                max_attempts,
            )
        if row is None:
            return None
        return int(row["identity_forge_count"])

    async def get_identity_forge_count(self, *, phone_number: str) -> int | None:
        if self._pool is None:
            return None
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT identity_forge_count
                FROM user_profiles
                WHERE phone_number = $1
                LIMIT 1
                """,
                phone_number,
            )
        if row is None:
            return None
        return int(row["identity_forge_count"])

    async def save_chat_message(
        self,
        *,
        room_id: str,
        sender: str,
        content: str,
        timestamp: str,
    ) -> None:
        if self._pool is None:
            return
        async with self._pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO chat_messages (room_id, sender, content, timestamp)
                VALUES ($1, $2, $3, $4)
                """,
                room_id,
                sender,
                content,
                timestamp,
            )

    async def list_chat_messages(self, *, room_id: str, limit: int) -> list[dict[str, Any]]:
        if self._pool is None:
            return []
        async with self._pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT id, room_id, sender, content, timestamp
                FROM chat_messages
                WHERE room_id = $1
                ORDER BY timestamp DESC
                LIMIT $2
                """,
                room_id,
                max(1, limit),
            )
        return [
            {
                "id": int(row["id"]),
                "room_id": str(row["room_id"]),
                "sender": str(row["sender"]),
                "content": str(row["content"]),
                "timestamp": str(row["timestamp"]),
            }
            for row in rows
        ]

