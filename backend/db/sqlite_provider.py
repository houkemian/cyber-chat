from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from db.base import DatabaseProvider


class SQLiteProvider(DatabaseProvider):
    name = "sqlite"

    def __init__(self, *, sqlite_path: str) -> None:
        self.sqlite_path = sqlite_path
        self._conn: sqlite3.Connection | None = None

    async def connect(self) -> None:
        db_file = Path(self.sqlite_path)
        db_file.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(db_file)
        self._conn.execute("PRAGMA journal_mode=WAL;")
        self._conn.execute("PRAGMA foreign_keys=ON;")
        # 为后续聊天室持久化预留结构（当前版本可不写入）。
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS room_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_name TEXT NOT NULL,
                sender TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS user_profiles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                phone_number TEXT NOT NULL UNIQUE,
                cyber_name TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_id TEXT NOT NULL,
                sender TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL
            )
            """
        )
        self._conn.commit()

    async def disconnect(self) -> None:
        if self._conn is None:
            return
        self._conn.close()
        self._conn = None

    async def healthcheck(self) -> bool:
        if self._conn is None:
            return False
        self._conn.execute("SELECT 1")
        return True

    async def get_user_cyber_name(self, *, phone_number: str) -> str | None:
        if self._conn is None:
            return None
        cursor = self._conn.execute(
            "SELECT cyber_name FROM user_profiles WHERE phone_number = ? LIMIT 1",
            (phone_number,),
        )
        row = cursor.fetchone()
        if row is None:
            return None
        return str(row[0])

    async def create_user_profile(self, *, phone_number: str, cyber_name: str) -> bool:
        if self._conn is None:
            return False
        cursor = self._conn.execute(
            """
            INSERT OR IGNORE INTO user_profiles (phone_number, cyber_name, created_at)
            VALUES (?, ?, ?)
            """,
            (phone_number, cyber_name, datetime.now(tz=timezone.utc).isoformat()),
        )
        self._conn.commit()
        return cursor.rowcount == 1

    async def update_user_cyber_name(self, *, phone_number: str, cyber_name: str) -> bool:
        if self._conn is None:
            return False
        cursor = self._conn.execute(
            "UPDATE user_profiles SET cyber_name = ? WHERE phone_number = ?",
            (cyber_name, phone_number),
        )
        self._conn.commit()
        return cursor.rowcount > 0

    async def save_chat_message(
        self,
        *,
        room_id: str,
        sender: str,
        content: str,
        timestamp: str,
    ) -> None:
        if self._conn is None:
            return
        self._conn.execute(
            """
            INSERT INTO chat_messages (room_id, sender, content, timestamp)
            VALUES (?, ?, ?, ?)
            """,
            (room_id, sender, content, timestamp),
        )
        self._conn.commit()

    async def list_chat_messages(self, *, room_id: str, limit: int) -> list[dict[str, str | int]]:
        if self._conn is None:
            return []
        cursor = self._conn.execute(
            """
            SELECT id, room_id, sender, content, timestamp
            FROM chat_messages
            WHERE room_id = ?
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            (room_id, limit),
        )
        rows = cursor.fetchall()
        return [
            {
                "id": int(row[0]),
                "room_id": str(row[1]),
                "sender": str(row[2]),
                "content": str(row[3]),
                "timestamp": str(row[4]),
            }
            for row in rows
        ]

