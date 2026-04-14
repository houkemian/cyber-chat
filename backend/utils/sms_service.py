from __future__ import annotations

import logging
from typing import Any

from core.settings import get_settings
from utils.sms_mock import sms_service as mock_sms_service

logger = logging.getLogger("sms-service")


class SMSService:
    async def send_code(self, phone_number: str) -> None:
        settings = get_settings()
        if settings.sms_provider == "aliyun":
            sent = await self._send_aliyun_code(phone_number)
            if sent:
                return
            logger.warning("aliyun sms send failed, fallback to mock provider")
        await mock_sms_service.send_code(phone_number)

    async def verify_code(self, phone_number: str, sms_code: str) -> bool:
        # 验证码校验仍走本地缓存，避免把明文 code 发送到前端之外的链路。
        return await mock_sms_service.verify_code(phone_number, sms_code)

    async def _send_aliyun_code(self, phone_number: str) -> bool:
        settings = get_settings()
        if (
            not settings.aliyun_access_key_id
            or not settings.aliyun_access_key_secret
            or not settings.aliyun_sms_sign_name
            or not settings.aliyun_sms_template_code
        ):
            return False
        try:
            from alibabacloud_tea_openapi import models as open_api_models
            from alibabacloud_tea_util import models as util_models
            from alibabacloud_dysmsapi20170525 import models as dysms_models
            from alibabacloud_dysmsapi20170525.client import Client as DysmsClient
        except Exception:
            logger.exception("aliyun sms sdk not installed")
            return False

        try:
            await mock_sms_service.send_code(phone_number)
            record: dict[str, Any] | None = mock_sms_service._store.get(phone_number)  # type: ignore[attr-defined]
            if not record:
                return False

            code = str(record.get("code", "")).strip()
            if not code:
                return False

            config = open_api_models.Config(
                access_key_id=settings.aliyun_access_key_id,
                access_key_secret=settings.aliyun_access_key_secret,
            )
            config.endpoint = "dysmsapi.aliyuncs.com"
            client = DysmsClient(config)
            request = dysms_models.SendSmsRequest(
                phone_numbers=phone_number,
                sign_name=settings.aliyun_sms_sign_name,
                template_code=settings.aliyun_sms_template_code,
                template_param=f'{{"code":"{code}"}}',
            )
            runtime = util_models.RuntimeOptions()
            response = client.send_sms_with_options(request, runtime)
            body_code = getattr(getattr(response, "body", None), "code", "")
            if body_code != "OK":
                logger.error("aliyun sms send error: %s", body_code)
                return False
            return True
        except Exception:
            logger.exception("aliyun sms send exception")
            return False


sms_service = SMSService()
