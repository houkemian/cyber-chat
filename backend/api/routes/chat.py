from __future__ import annotations

import os
from datetime import datetime, timezone

import jwt
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, WebSocketException, status

from models import RoomHistoryMessage
from utils.ws_manager import ws_manager

router = APIRouter(tags=["chat"])


async def content_moderation(raw_text: str) -> str:
    """
    内容安全拦截占位：
    当前直通，后续可在此接入敏感词/风控 SDK。
    """
    return raw_text


def _extract_token(websocket: WebSocket) -> str | None:
    """
    读取接入令牌（优先级）：
    1) Query: ?token=...
    2) Header: Authorization: Bearer <token>
    3) Header: X-Token: <token>
    """
    token_from_query = websocket.query_params.get("token")
    if token_from_query:
        return token_from_query

    auth_header = websocket.headers.get("authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        return auth_header[7:].strip()

    token_from_header = websocket.headers.get("x-token")
    if token_from_header:
        return token_from_header.strip()

    return None


def _parse_cyber_name(token: str) -> str:
    """
    验证 JWT 并提取 cyber_name。
    无效令牌统一抛出 1008，拒绝接入策略违规连接。
    """
    secret_key = os.getenv("JWT_SECRET", "dev-secret-change-me-in-prod")
    try:
        payload = jwt.decode(token, secret_key, algorithms=["HS256"])
    except jwt.InvalidTokenError as exc:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION) from exc

    cyber_name = payload.get("cyber_name")
    if not isinstance(cyber_name, str) or not cyber_name.strip():
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION)

    return cyber_name.strip()


def _normalize_room_id(room_id: str) -> str:
    normalized = room_id.strip()
    return normalized or "lobby"


@router.websocket("/ws/{room_id}")
async def chat_ws(websocket: WebSocket, room_id: str) -> None:
    """
    实时聊天室 WebSocket：
    - 鉴权通过后接入
    - 接收文本消息并广播到指定扇区
    - 上下线在指定扇区内发 system 事件
    """
    room = _normalize_room_id(room_id)
    token = _extract_token(websocket)
    if not token:
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION)

    cyber_name = _parse_cyber_name(token)
    await ws_manager.connect(websocket, room)

    await ws_manager.broadcast_json(
        {
            "type": "system",
            "content": f"[系统]: 终端 <{cyber_name}> 已接入扇区 <{room}>。",
            "timestamp": datetime.now(tz=timezone.utc).isoformat(),
            "online_count": ws_manager.get_room_count(room),
        },
        room,
    )

    try:
        while True:
            raw_text = await websocket.receive_text()
            sanitized_text = (await content_moderation(raw_text)).strip()
            if not sanitized_text:
                continue

            timestamp = datetime.now(tz=timezone.utc).isoformat()
            message_payload = {
                "type": "chat",
                "sender": cyber_name,
                "content": sanitized_text,
                "timestamp": timestamp,
            }

            # 广播钩子：每条聊天消息异步持久化，写库异常不阻断实时消息链路。
            db_manager = websocket.app.state.db
            try:
                await db_manager.save_chat_message(
                    room_id=room,
                    sender=cyber_name,
                    content=sanitized_text,
                    timestamp=timestamp,
                )
            except Exception:
                pass

            await ws_manager.broadcast_json(
                message_payload,
                room,
            )
    except WebSocketDisconnect:
        await ws_manager.disconnect(websocket, room)
        await ws_manager.broadcast_json(
            {
                "type": "system",
                "content": f"[系统]: 终端 <{cyber_name}> 已断开扇区 <{room}>。",
                "timestamp": datetime.now(tz=timezone.utc).isoformat(),
                "online_count": ws_manager.get_room_count(room),
            },
            room,
        )


@router.get("/chat/history/{room_id}", response_model=list[RoomHistoryMessage])
async def chat_history(
    room_id: str,
    limit: int = Query(default=200, ge=1, le=200),
) -> list[RoomHistoryMessage]:
    """
    拉取房间历史消息（正序，最多 200 条）：
    - room_id: 扇区标识
    - limit: 单次返回条数，默认 200
    """
    room = _normalize_room_id(room_id)
    records = await ws_manager.get_room_history(room_id=room, limit=limit)
    return [RoomHistoryMessage.model_validate(record) for record in records]
