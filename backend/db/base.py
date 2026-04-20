from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class DatabaseProvider(ABC):
    name: str

    @abstractmethod
    async def connect(self) -> None:
        raise NotImplementedError

    @abstractmethod
    async def disconnect(self) -> None:
        raise NotImplementedError

    @abstractmethod
    async def healthcheck(self) -> bool:
        raise NotImplementedError

    @abstractmethod
    async def get_user_cyber_name(self, *, phone_number: str) -> str | None:
        raise NotImplementedError

    @abstractmethod
    async def create_user_profile(self, *, phone_number: str, cyber_name: str) -> bool:
        """
        首次登录写入用户档案。
        返回值：True 表示本次成功创建；False 表示已存在或创建失败。
        """
        raise NotImplementedError

    @abstractmethod
    async def update_user_cyber_name(self, *, phone_number: str, cyber_name: str) -> bool:
        """更新已有档案的赛博名；成功更新至少一行返回 True。"""
        raise NotImplementedError

    @abstractmethod
    async def increment_identity_forge_count(
        self,
        *,
        phone_number: str,
        max_attempts: int,
    ) -> int | None:
        """
        伪造身份计数 +1（仅当未达到上限）。
        返回值：更新后的计数；若不存在用户或已达上限则返回 None。
        """
        raise NotImplementedError

    @abstractmethod
    async def get_identity_forge_count(self, *, phone_number: str) -> int | None:
        """读取用户已使用的伪造次数；不存在返回 None。"""
        raise NotImplementedError

    @abstractmethod
    async def save_chat_message(
        self,
        *,
        room_id: str,
        sender: str,
        content: str,
        timestamp: str,
    ) -> None:
        raise NotImplementedError

    @abstractmethod
    async def list_chat_messages(self, *, room_id: str, limit: int) -> list[dict[str, Any]]:
        raise NotImplementedError

