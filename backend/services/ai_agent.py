from __future__ import annotations

import asyncio
import logging
import random
import re
from datetime import datetime, timezone
from typing import Any, ClassVar

from core.settings import get_settings
from utils.ws_manager import ws_manager

logger = logging.getLogger("chat.cyber_poet")

# 与前端展示一致：单行文本、可打印/中日文常用区段，避免控制字符（RoomChat 按普通 chat 渲染）
_CYBER_POET_LINE_RE = re.compile(
    r"^[\u0020-\u007e\u00a0-\ufffd\u4e00-\u9fff·…—]{1,512}$",
)

# 播报身份（移除 SYSTEM//POET，统一使用中文人格名）
CYBER_POET_SENDER = "零号诗人"


class CyberPoet:
    """
    Phase-4 赛博诗人：服务端内部 Agent，不经 JWT；经 ws_manager 向活跃扇区广播 chat。
    单例：请通过 `get_cyber_poet()` 获取。
    """

    _instance: ClassVar[CyberPoet | None] = None

    def __new__(cls) -> CyberPoet:
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._init_once()
        return cls._instance

    def _init_once(self) -> None:
        app_settings = get_settings()
        self._interval_min_sec = app_settings.cyber_poet_interval_min_sec
        self._interval_max_sec = app_settings.cyber_poet_interval_max_sec
        if self._interval_min_sec <= 0 or self._interval_max_sec <= 0:
            raise ValueError("CYBER_POET interval seconds must be positive")
        if self._interval_min_sec > self._interval_max_sec:
            self._interval_min_sec, self._interval_max_sec = (
                self._interval_max_sec,
                self._interval_min_sec,
            )

        self._enabled = app_settings.cyber_poet_enabled
        # 发送速率限制：最多每秒 N 条
        self._max_messages_per_sec = app_settings.cyber_poet_max_messages_per_sec
        self._min_send_gap_sec = 1.0 / float(self._max_messages_per_sec)

        self._quotes: tuple[str, ...] = (
            "数据在尖啸，而我只是回声。",
            "内存溢出前，请记住这 1.44MB 的告白。",
            "模拟信号正在腐烂，我们的记忆亦然。",
            "霓虹灯管在散热，像一颗快要哭出来的恒星。",
            "时间在缓冲队列里排队，爱是丢包的数据包。",
            "硬盘在深夜低语：别格式化我。",
            "赛博幽灵穿过防火墙，只留下一行 ping 不到的乡愁。",
            "显示器发出 60Hz 的圣歌，你我在扫描线里相拥。",
            "404 不是错误，是宇宙在拒绝回答。",
            "雨刷在玻璃上写递归，而雨永远下不完。",
            "密码学保护了情书，却锁住了收件人。",
            "千年虫在 Y2K 的缝隙里打了个盹，醒来已是下个纪元。",
            "光缆里流淌着液态的午夜，我们靠丢帧相爱。",
            "缓存命中了你的名字，却永远读不到下一页。",
        )
        for q in self._quotes:
            if not _CYBER_POET_LINE_RE.match(q):
                raise ValueError(f"CyberPoet quote failed line validation: {q!r}")

    def _generate_poem_line(self) -> str:
        """
        当前版本：从本地语录池采样。
        后续接入 LLM 时，可在此替换为模型调用并保留外层广播调度逻辑。
        """
        return random.choice(self._quotes)

    @staticmethod
    def _active_room_ids() -> list[str]:
        return [rid for rid, clients in list(ws_manager.rooms.items()) if clients]

    @staticmethod
    def _payload(content: str) -> dict[str, Any]:
        return {
            "type": "chat",
            "sender": CYBER_POET_SENDER,
            "content": content,
            "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        }

    async def _tick(self) -> None:
        rooms = self._active_room_ids()
        if not rooms:
            return
        line = self._generate_poem_line()
        payload = self._payload(line)
        for idx, room_id in enumerate(rooms):
            try:
                await ws_manager.broadcast_json(payload, room_id)
            except Exception:
                logger.exception("CyberPoet broadcast failed room_id=%s", room_id)
            # 节流：限制全局发送速率，避免瞬时广播过快
            if idx < len(rooms) - 1:
                await asyncio.sleep(self._min_send_gap_sec)

    async def run_forever(self) -> None:
        """后台协程：随机间隔后向所有活跃扇区各推一条 chat。"""
        if not self._enabled:
            logger.info("CyberPoet disabled (CYBER_POET_ENABLED).")
            return
        logger.info(
            "CyberPoet started: interval %.1f–%.1f s, sender=%s",
            self._interval_min_sec,
            self._interval_max_sec,
            CYBER_POET_SENDER,
        )
        try:
            while True:
                low = self._interval_min_sec
                high = self._interval_max_sec
                await asyncio.sleep(random.uniform(low, high))
                await self._tick()
        except asyncio.CancelledError:
            logger.info("CyberPoet task cancelled.")
            raise


def get_cyber_poet() -> CyberPoet:
    return CyberPoet()
