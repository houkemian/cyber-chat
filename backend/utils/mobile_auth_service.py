from __future__ import annotations

import logging
import re

from core.settings import get_settings

logger = logging.getLogger("mobile-auth")
MOBILE_TOKEN_PATTERN = re.compile(r"^mock:(\d{6,32})$")


class MobileAuthService:
    async def verify_access_token(self, access_token: str) -> str | None:
        settings = get_settings()
        if settings.mobile_login_provider == "aliyun":
            mobile = await self._verify_with_aliyun(access_token)
            if mobile:
                return mobile
            logger.warning("aliyun mobile auth verify failed")
            return None
        return self._verify_with_mock(access_token)

    def _verify_with_mock(self, access_token: str) -> str | None:
        token = access_token.strip()
        match = MOBILE_TOKEN_PATTERN.match(token)
        if not match:
            return None
        return match.group(1)

    async def _verify_with_aliyun(self, access_token: str) -> str | None:
        settings = get_settings()
        if not settings.aliyun_access_key_id or not settings.aliyun_access_key_secret:
            return None
        try:
            from alibabacloud_tea_openapi import models as open_api_models
            from alibabacloud_tea_util import models as util_models
            from alibabacloud_dypnsapi20170525 import models as dypns_models
            from alibabacloud_dypnsapi20170525.client import Client as DypnsClient
        except Exception:
            logger.exception("aliyun dypns sdk not installed")
            return None

        try:
            config = open_api_models.Config(
                access_key_id=settings.aliyun_access_key_id,
                access_key_secret=settings.aliyun_access_key_secret,
            )
            config.endpoint = "dypnsapi.aliyuncs.com"
            client = DypnsClient(config)
            request = dypns_models.GetMobileRequest(access_token=access_token)
            runtime = util_models.RuntimeOptions()
            response = client.get_mobile_with_options(request, runtime)
            body = getattr(response, "body", None)
            code = getattr(body, "code", "")
            if code != "OK":
                logger.error("aliyun get_mobile failed: %s", code)
                return None
            result_obj = getattr(body, "get_mobile_result_d_o", None)
            mobile = getattr(result_obj, "mobile", None)
            if isinstance(mobile, str) and mobile:
                return mobile
            return None
        except Exception:
            logger.exception("aliyun get_mobile exception")
            return None


mobile_auth_service = MobileAuthService()
