from __future__ import annotations

import logging
import secrets
from datetime import datetime, timezone
from typing import Any

from core.settings import get_settings
from utils.sms_mock import sms_service as mock_sms_service

logger = logging.getLogger("sms-service")
logger.setLevel(logging.INFO)


def _log_ts() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


class SMSService:
    def __init__(self) -> None:
        self._redis_client: Any | None = None

    async def _get_redis(self) -> Any | None:
        if self._redis_client is not None:
            return self._redis_client
        settings = get_settings()
        try:
            import redis.asyncio as redis
        except Exception:
            logger.exception("[SMS_REDIS_IMPORT_ERROR] ts=%s", _log_ts())
            return None
        try:
            client = redis.from_url(settings.redis_dsn, encoding="utf-8", decode_responses=True)
            await client.ping()
            self._redis_client = client
            return self._redis_client
        except Exception:
            logger.exception("[SMS_REDIS_CONNECT_ERROR] ts=%s", _log_ts())
            return None

    @staticmethod
    def _sms_code_key(phone_number: str) -> str:
        return f"sms:code:{phone_number}"

    async def send_code(self, phone_number: str) -> None:
        settings = get_settings()
        if settings.sms_provider == "aliyun":
            sent = await self._send_aliyun_code(phone_number)
            if sent:
                return
            logger.warning("[ALIYUN_SMS_FALLBACK] ts=%s msg=%s", _log_ts(), "aliyun sms send failed, fallback to mock provider")
        await mock_sms_service.send_code(phone_number)

    async def verify_code(self, phone_number: str, sms_code: str) -> bool:
        settings = get_settings()
        if settings.sms_provider == "aliyun":
            return await self._check_aliyun_code(phone_number=phone_number, sms_code=sms_code)
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
            from alibabacloud_dypnsapi20170525 import models as dypns_models
            from alibabacloud_dypnsapi20170525.client import Client as DypnsClient
        except Exception:
            logger.exception("[ALIYUN_SMS_SDK_ERROR] ts=%s msg=%s", _log_ts(), "aliyun sms sdk not installed")
            return False

        try:
            code = "".join(str(secrets.randbelow(10)) for _ in range(4))
            config = open_api_models.Config(
                access_key_id=settings.aliyun_access_key_id,
                access_key_secret=settings.aliyun_access_key_secret,
            )
            config.endpoint = "dypnsapi.aliyuncs.com"
            client = DypnsClient(config)
            request = dypns_models.SendSmsVerifyCodeRequest(
                phone_number=phone_number,
                sign_name=settings.aliyun_sms_sign_name,
                template_code=settings.aliyun_sms_template_code,
                template_param=f"{{\"code\":\"{code}\",\"min\":\"5\"}}"
            )
            logger.warning(
                "[ALIYUN_SMS_REQ] ts=%s action=SendSmsVerifyCodeRequest phone_number=%s sign_name=%s template_code=%s",
                _log_ts(),
                request.phone_number,
                request.sign_name,
                request.template_code,
            )
            runtime = util_models.RuntimeOptions()
            response = client.send_sms_verify_code_with_options(request, runtime)
            body = getattr(response, "body", None)
            verify_id = str(
                getattr(body, "verify_id", "")
                or getattr(body, "biz_id", "")
                or getattr(body, "request_id", "")
            ).strip()
            redis_client = await self._get_redis()
            if redis_client is None:
                logger.error("[SMS_REDIS_UNAVAILABLE] ts=%s phone_number=%s", _log_ts(), phone_number)
                return False
            await redis_client.set(self._sms_code_key(phone_number), code, ex=300)
            logger.warning(
                "[ALIYUN_SMS_RESP] ts=%s code=%s message=%s request_id=%s biz_id=%s",
                _log_ts(),
                getattr(body, "code", ""),
                getattr(body, "message", ""),
                getattr(body, "request_id", ""),
                getattr(body, "biz_id", ""),
            )
            body_code = getattr(getattr(response, "body", None), "code", "")
            if body_code != "OK":
                logger.error("[ALIYUN_SMS_ERROR] ts=%s code=%s", _log_ts(), body_code)
                return False
            return True
        except Exception:
            logger.exception("[ALIYUN_SMS_EXCEPTION] ts=%s msg=%s", _log_ts(), "aliyun sms send exception")
            return False

    async def _check_aliyun_code(self, phone_number: str, sms_code: str) -> bool:
        redis_client = await self._get_redis()
        if redis_client is None:
            logger.error("[SMS_REDIS_UNAVAILABLE] ts=%s phone_number=%s", _log_ts(), phone_number)
            return False

        expected_code = await redis_client.get(self._sms_code_key(phone_number))
        expected_code = str(expected_code or "").strip()
        passed = bool(expected_code) and expected_code == str(sms_code).strip()
        logger.warning(
            "[LOCAL_SMS_CHECK] ts=%s phone_number=%s passed=%s",
            _log_ts(),
            phone_number,
            passed,
        )
        if passed:
            await redis_client.delete(self._sms_code_key(phone_number))
        return passed


sms_service = SMSService()
