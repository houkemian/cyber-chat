from __future__ import annotations

from pydantic import BaseModel


class ChatMessage(BaseModel):
    id: int
    room_id: str
    sender: str
    content: str
    timestamp: str


class RoomHistoryMessage(BaseModel):
    type: str
    content: str
    timestamp: str
    sender: str | None = None

