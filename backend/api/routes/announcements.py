from __future__ import annotations

from fastapi import APIRouter, Request

from schemas.announcements import AnnouncementsResponse
from services.announcements_cache import get_announcements

router = APIRouter(tags=["announcements"])


@router.get("/announcements", response_model=AnnouncementsResponse)
async def list_announcements(request: Request) -> AnnouncementsResponse:
    """公告列表：应用缓存（内存 / Redis）。"""
    cache = request.app.state.cache
    items = await get_announcements(cache)
    return AnnouncementsResponse(items=items)
