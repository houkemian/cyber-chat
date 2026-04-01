from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import jwt

# ── JWT 工具层 ───────────────────────────────────────────────
# 使用 HS256 对称签名；生产环境请将 JWT_SECRET 写入 .env


def create_access_token(
    *,
    secret_key: str,
    payload: dict[str, Any],
    expires_delta: timedelta | None = None,
) -> str:
    """签发一枚时控访问令牌，默认有效期 24 小时。"""
    expire = datetime.now(tz=timezone.utc) + (expires_delta or timedelta(hours=24))
    to_encode = {**payload, "exp": expire}
    return jwt.encode(to_encode, secret_key, algorithm="HS256")
