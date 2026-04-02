from __future__ import annotations

from cache.manager import CacheManager
from schemas.announcements import AnnouncementItem

CACHE_KEY_ANNOUNCEMENTS = "announcements:v1"

# 默认公告：首次读缓存未命中时写入；后续可由管理接口或运维脚本更新缓存
_DEFAULT_RAW: list[dict[str, str]] = [
    {
        "id": "ann-1",
        "content": (
            "欢迎接入赛博树洞 2000.exe · 禁止实名，允许发疯。"
            "本地消息列表最多保留最近 200 条，与频道历史同步上限一致。"
        ),
    },
    {
        "id": "ann-2",
        "content": "当前节点状态稳定 · 多扇区同步运行中 · 请文明发言，共同维护数字秩序。",
    },
    {
        "id": "ann-3",
        "content": "系统公告：Phase-3 升级中 · AI 气氛组即将接入 · 敬请期待更多赛博体验。",
    },
]


def _normalize_items(raw: object) -> list[AnnouncementItem] | None:
    if not isinstance(raw, list):
        return None
    out: list[AnnouncementItem] = []
    for row in raw:
        if not isinstance(row, dict):
            return None
        try:
            out.append(AnnouncementItem.model_validate(row))
        except Exception:
            return None
    return out if out else None


async def get_announcements(cache: CacheManager) -> list[AnnouncementItem]:
    """
    从缓存读取公告列表；未命中则写入默认列表（无 TTL，驻留至进程结束或 Redis 键被删）。
    切换为 Redis 时，同一 key、同一结构，由 CacheProvider 序列化即可。
    """
    provider = cache.provider
    raw = await provider.get(CACHE_KEY_ANNOUNCEMENTS)
    parsed = _normalize_items(raw) if raw is not None else None

    if parsed is not None:
        return parsed

    await provider.set(CACHE_KEY_ANNOUNCEMENTS, list(_DEFAULT_RAW), ttl_seconds=None)
    return [AnnouncementItem.model_validate(x) for x in _DEFAULT_RAW]
