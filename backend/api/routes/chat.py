from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

import jwt
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, WebSocketException, status

from core.settings import get_settings
from models import RoomHistoryMessage, RoomMembersResponse
from services.llm_agent import room_agent_manager
from utils.cyber_filter import dfa_filter
from utils.ws_manager import ws_manager

router = APIRouter(tags=["chat"])
logger = logging.getLogger("chat.router")


def _fire_and_forget_room_agent(room_id: str, sender: str, content: str) -> None:
    """
    非阻塞触发 AI 人格代理；避免影响 WS 主链路。
    """
    task = asyncio.create_task(
        room_agent_manager.process_message(room_id=room_id, sender=sender, content=content),
        name=f"room-agent:{room_id}",
    )
    def _on_done(done_task: asyncio.Task) -> None:
        if done_task.cancelled():
            return
        exc = done_task.exception()
        if exc is not None:
            logger.exception("Room agent task failed room=%s", room_id, exc_info=exc)

    task.add_done_callback(_on_done)


async def content_moderation(raw_text: str) -> str:
    """内容安全拦截：基于 DFA 词库替换敏感片段。"""
    is_dirty, sanitized = dfa_filter.check_and_replace(raw_text)
    if is_dirty:
        logger.warning("Content moderated in chat message")
    return sanitized


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
    secret_key = get_settings().jwt_secret
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
    await ws_manager.connect(websocket, room, cyber_name)

    await ws_manager.broadcast_json(
        {
            "type": "system",
            "content": f"[系统]: 终端 <{cyber_name}> 已接入扇区 <{room}>。",
            "timestamp": datetime.now(tz=timezone.utc).isoformat(),
            "online_count": ws_manager.get_room_count(room),
        },
        room,
    )

    disconnected = False
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
            _fire_and_forget_room_agent(room_id=room, sender=cyber_name, content=sanitized_text)
    except WebSocketDisconnect:
        disconnected = True
    except RuntimeError:
        # 某些情况下底层已断链但 Starlette 未抛 WebSocketDisconnect，统一按断开处理。
        disconnected = True
    finally:
        if disconnected:
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


@router.get("/ws/rooms/{room_id}/members", response_model=RoomMembersResponse)
async def room_members(room_id: str) -> RoomMembersResponse:
    """
    当前扇区在线成员列表（来源于连接池，cyber_name 去重）：
    与 WS 广播中的 online_count（去重人数）一致。
    """
    room = _normalize_room_id(room_id)
    members = await ws_manager.get_room_members(room)
    return RoomMembersResponse(members=members, online_count=len(members))


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
