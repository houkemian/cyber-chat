from __future__ import annotations

from pydantic import BaseModel, Field


class AnnouncementItem(BaseModel):
    id: str = Field(..., min_length=1)
    content: str = Field(..., min_length=1)


class AnnouncementsResponse(BaseModel):
    """GET /api/announcements — 公告列表（由缓存提供，默认内存，可切换 Redis）。"""

    items: list[AnnouncementItem]
