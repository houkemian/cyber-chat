from __future__ import annotations

import asyncio
import json
import logging
from collections import deque
from typing import Any

from fastapi import WebSocket

logger = logging.getLogger("chat.ws_manager")

MAX_ROOM_HISTORY = 200


class ConnectionManager:
    """
    赛博信道连接管理器：
    - 维护分房间在线连接池
    - 统一处理连接建立/断开
    - 广播 JSON 消息到指定扇区
    """

    def __init__(self) -> None:
        self.rooms: dict[str, list[WebSocket]] = {}
        self.histories: dict[str, deque[dict[str, Any]]] = {}
        self._room_locks: dict[str, asyncio.Lock] = {}
        self._locks_guard = asyncio.Lock()
        self._redis = None

    async def configure_redis(self, dsn: str) -> None:
        """初始化 Redis 客户端（失败时自动降级内存缓存）。"""
        try:
            import redis.asyncio as redis
        except ImportError:
            logger.warning("[HISTORY] redis package is missing, using memory-only history.")
            self._redis = None
            return

        client = redis.from_url(dsn, encoding="utf-8", decode_responses=True)
        try:
            await client.ping()
        except Exception:
            logger.exception("[HISTORY] Redis connect failed, using memory-only history.")
            await client.aclose()
            self._redis = None
            return

        self._redis = client

    async def close(self) -> None:
        if self._redis is None:
            return
        await self._redis.aclose()
        self._redis = None

    async def _get_room_lock(self, room_id: str) -> asyncio.Lock:
        async with self._locks_guard:
            room_lock = self._room_locks.get(room_id)
            if room_lock is None:
                room_lock = asyncio.Lock()
                self._room_locks[room_id] = room_lock
            return room_lock

    async def _cache_history(self, payload: dict[str, Any], room_id: str) -> None:
        if payload.get("type") != "chat":
            return

        room_lock = await self._get_room_lock(room_id)
        payload_record = dict(payload)

        async with room_lock:
            room_history = self.histories.get(room_id)
            if room_history is None:
                room_history = deque(maxlen=MAX_ROOM_HISTORY)
                self.histories[room_id] = room_history
            room_history.append(payload_record)

        if self._redis is None:
            return

        history_key = f"chat:history:{room_id}"
        serialized_payload = json.dumps(payload_record, ensure_ascii=False)
        try:
            async with self._redis.pipeline(transaction=True) as pipe:
                pipe.lpush(history_key, serialized_payload)
                pipe.ltrim(history_key, 0, MAX_ROOM_HISTORY - 1)
                await pipe.execute()
        except Exception:
            logger.exception("[HISTORY] Redis write failed, key=%s", history_key)

    async def get_room_history(self, room_id: str, limit: int = MAX_ROOM_HISTORY) -> list[dict[str, Any]]:
        effective_limit = max(1, min(limit, MAX_ROOM_HISTORY))

        if self._redis is not None:
            history_key = f"chat:history:{room_id}"
            try:
                redis_records = await self._redis.lrange(history_key, 0, effective_limit - 1)
                if redis_records:
                    parsed_records = [json.loads(item) for item in redis_records]
                    parsed_records = [item for item in parsed_records if item.get("type") == "chat"]
                    parsed_records.reverse()
                    return parsed_records
            except Exception:
                logger.exception("[HISTORY] Redis read failed, key=%s", history_key)

        room_lock = await self._get_room_lock(room_id)
        async with room_lock:
            room_history = self.histories.get(room_id)
            if not room_history:
                return []
            return [item for item in list(room_history)[-effective_limit:] if item.get("type") == "chat"]

    async def connect(self, websocket: WebSocket, room_id: str) -> None:
        """接入上行链路并登记到指定扇区连接池。"""
        await websocket.accept()
        room_lock = await self._get_room_lock(room_id)
        async with room_lock:
            if room_id not in self.rooms:
                self.rooms[room_id] = []
            self.rooms[room_id].append(websocket)

    async def disconnect(self, websocket: WebSocket, room_id: str) -> None:
        """终止上行链路并移出指定扇区连接池。"""
        room_lock = await self._get_room_lock(room_id)
        async with room_lock:
            room_connections = self.rooms.get(room_id)
            if not room_connections:
                return
            if websocket in room_connections:
                room_connections.remove(websocket)
            # 房间无人后清理 key，避免字典无限膨胀
            if not room_connections:
                self.rooms.pop(room_id, None)

    async def broadcast_json(self, payload: dict[str, Any], room_id: str) -> None:
        """
        向指定扇区在线终端广播 JSON。
        若某连接发送失败，自动剔除，避免拖垮整体广播链路。
        """
        await self._cache_history(payload=payload, room_id=room_id)

        room_lock = await self._get_room_lock(room_id)
        async with room_lock:
            room_connections = list(self.rooms.get(room_id, []))
        if not room_connections:
            return

        stale_connections: list[WebSocket] = []
        for connection in room_connections:
            try:
                await connection.send_json(payload)
            except Exception:
                stale_connections.append(connection)

        for connection in stale_connections:
            await self.disconnect(connection, room_id)


# 单例：整个服务共享一套连接池
ws_manager = ConnectionManager()
