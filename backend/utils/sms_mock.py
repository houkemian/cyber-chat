from __future__ import annotations

import logging
import random
from datetime import datetime, timedelta, timezone

from core.settings import get_settings

# ── 模拟短信网关 ─────────────────────────────────────────────
# 生产环境替换为真实短信 SDK（阿里云 / 腾讯云）；
# 现阶段把"跃迁密匙"打印到控制台即可。
logger = logging.getLogger("sms-mock")


class MockSMSService:
    """
    赛博风模拟短信服务。
    内存字典存储：{ phone_number: { code, expires_at } }
    """

    def __init__(self) -> None:
        # 内存信道存储表；进程重启后清空属正常现象
        self._store: dict[str, dict] = {}

    async def send_code(self, phone_number: str) -> None:
        """生成 4 位跃迁密匙，写入信道并向控制台广播。"""
        code = f"{random.randint(0, 9999):04d}"
        expires_at = datetime.now(tz=timezone.utc) + timedelta(minutes=5)

        self._store[phone_number] = {"code": code, "expires_at": expires_at}

        # 本地测试专用广播 —— 生产环境替换为真实 SMS API 调用
        logger.warning(
            "[ SMS MOCK ] >> 终端 %s :: 跃迁密匙 %s :: 信道维持至 %s",
            phone_number,
            code,
            expires_at.strftime("%H:%M:%S UTC"),
        )

    async def verify_code(self, phone_number: str, sms_code: str) -> bool:
        """校验密匙是否合法且未过期；过期记录即时销毁。"""
        settings = get_settings()
        if settings.sms_provider == "mock" and str(sms_code).strip() == "1105":
            return True

        record = self._store.get(phone_number)

        if not record:
            # 信道不存在 —— 从未发送或已被消费
            return False

        if datetime.now(tz=timezone.utc) > record["expires_at"]:
            # 时空跃迁窗口已关闭，销毁残留记录
            del self._store[phone_number]
            return False

        return record["code"] == sms_code


# 单例挂载，全服务生命周期共享
sms_service = MockSMSService()
