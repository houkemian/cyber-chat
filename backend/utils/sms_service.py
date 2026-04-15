from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from core.settings import get_settings
from utils.sms_mock import sms_service as mock_sms_service

logger = logging.getLogger("sms-service")
logger.setLevel(logging.INFO)


def _log_ts() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


class SMSService:
    def __init__(self) -> None:
        # 保存发送验证码返回的上下文，供 check 请求关联使用。
        self._aliyun_verify_ctx: dict[str, dict[str, str | datetime]] = {}

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
            # 仅在当前手机号已有阿里云发送上下文时走官方 check。
            if phone_number in self._aliyun_verify_ctx:
                verified = await self._check_aliyun_code(phone_number=phone_number, sms_code=sms_code)
                if verified:
                    return True
                return False
            logger.warning(
                "[ALIYUN_SMS_VERIFY_FALLBACK] ts=%s phone_number=%s msg=%s",
                _log_ts(),
                phone_number,
                "missing aliyun verify context, fallback to mock verify",
            )
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
            if verify_id:
                self._aliyun_verify_ctx[phone_number] = {
                    "verify_id": verify_id,
                    "expires_at": datetime.now(tz=timezone.utc) + timedelta(minutes=10),
                }
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
        settings = get_settings()
        try:
            from alibabacloud_tea_openapi import models as open_api_models
            from alibabacloud_tea_util import models as util_models
            from alibabacloud_dypnsapi20170525 import models as dypns_models
            from alibabacloud_dypnsapi20170525.client import Client as DypnsClient
        except Exception:
            logger.exception("[ALIYUN_SMS_SDK_ERROR] ts=%s msg=%s", _log_ts(), "aliyun sms sdk not installed for check")
            return False

        ctx = self._aliyun_verify_ctx.get(phone_number, {})
        expires_at = ctx.get("expires_at")
        if isinstance(expires_at, datetime) and datetime.now(tz=timezone.utc) > expires_at:
            self._aliyun_verify_ctx.pop(phone_number, None)
            logger.warning("[ALIYUN_SMS_CHECK_EXPIRED] ts=%s phone_number=%s", _log_ts(), phone_number)
            return False

        verify_id = str(ctx.get("verify_id", "")).strip()

        try:
            config = open_api_models.Config(
                access_key_id=settings.aliyun_access_key_id,
                access_key_secret=settings.aliyun_access_key_secret,
            )
            config.endpoint = "dypnsapi.aliyuncs.com"
            client = DypnsClient(config)
            request = dypns_models.CheckSmsVerifyCodeRequest(
                phone_number=phone_number,
                verify_code=sms_code,
                verify_id=verify_id or None,
            )
            logger.warning(
                "[ALIYUN_SMS_CHECK_REQ] ts=%s action=CheckSmsVerifyCodeRequest phone_number=%s verify_id=%s",
                _log_ts(),
                phone_number,
                verify_id,
            )
            runtime = util_models.RuntimeOptions()
            response = client.check_sms_verify_code_with_options(request, runtime)
            body = getattr(response, "body", None)
            body_code = str(getattr(body, "code", ""))
            verify_result = str(getattr(body, "verify_result", "")).lower()
            logger.warning(
                "[ALIYUN_SMS_CHECK_RESP] ts=%s code=%s message=%s verify_result=%s request_id=%s",
                _log_ts(),
                body_code,
                getattr(body, "message", ""),
                verify_result,
                getattr(body, "request_id", ""),
            )
            passed = body_code == "OK" and verify_result in ("true", "pass", "success", "1")
            if passed:
                self._aliyun_verify_ctx.pop(phone_number, None)
            return passed
        except Exception:
            logger.exception("[ALIYUN_SMS_CHECK_EXCEPTION] ts=%s msg=%s", _log_ts(), "aliyun sms check exception")
            return False


sms_service = SMSService()
