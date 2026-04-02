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


class RoomMembersResponse(BaseModel):
    """GET /api/ws/rooms/{room_id}/members — 当前扇区在线成员（按连接去重后的 cyber_name）。"""

    members: list[str]
    online_count: int

