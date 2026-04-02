from __future__ import annotations

import asyncio
import json

from services.llm_agent import RoomAgentManager
from utils.ws_manager import ws_manager


async def main() -> None:
    manager = RoomAgentManager()
    captured: list[tuple[str, dict]] = []

    async def fake_broadcast(payload: dict, room_id: str) -> None:
        captured.append((room_id, payload))
        print(f"[broadcast] room={room_id} type={payload.get('type')} payload={json.dumps(payload, ensure_ascii=False)}")

    original_broadcast = ws_manager.broadcast_json
    ws_manager.broadcast_json = fake_broadcast  # type: ignore[assignment]
    try:
        await manager.process_message(
            room_id="sector-404",
            sender="测试用户",
            content="@AI 今晚营业吗？给我一杯电子鸡尾酒。",
        )
    finally:
        ws_manager.broadcast_json = original_broadcast  # type: ignore[assignment]

    print(f"\nCaptured payload count: {len(captured)}")
    if len(captured) < 2:
        raise SystemExit("Expected both chat and system payloads, but not enough messages were emitted.")


if __name__ == "__main__":
    asyncio.run(main())

