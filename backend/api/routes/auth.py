from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Request

from core.settings import get_settings
from schemas.auth import AuthResponse, MobileVerifyRequest, SendKeyRequest, VerifyKeyRequest
from utils.cyber_filter import dfa_filter
from utils.generator import generate_cyber_name
from utils.security import create_access_token
from utils.mobile_auth_service import mobile_auth_service
from utils.sms_service import sms_service

router = APIRouter(tags=["auth"])


# ── content_moderation 依赖 ─────────────────────────────────
async def content_moderation(request: Request) -> None:
    """
    请求体内容安全拦截：
    - 对字符串字段执行 DFA 检测
    - 命中敏感词时拒绝请求
    """
    content_type = (request.headers.get("content-type") or "").lower()
    if "application/json" not in content_type:
        return
    try:
        payload = await request.json()
    except Exception:
        return
    if not isinstance(payload, dict):
        return

    for value in payload.values():
        if not isinstance(value, str):
            continue
        is_dirty, _ = dfa_filter.check_and_replace(value)
        if is_dirty:
            raise HTTPException(status_code=400, detail="content_blocked")


async def _issue_auth_response(request: Request, phone_number: str) -> AuthResponse:
    db_manager = request.app.state.db
    cyber_name = await db_manager.get_user_cyber_name(phone_number=phone_number)
    if not cyber_name:
        generated_name = generate_cyber_name()
        created = await db_manager.create_user_profile(
            phone_number=phone_number,
            cyber_name=generated_name,
        )
        if created:
            cyber_name = generated_name
        else:
            cyber_name = await db_manager.get_user_cyber_name(phone_number=phone_number)
            if not cyber_name:
                cyber_name = generated_name

    secret_key = get_settings().jwt_secret
    token = create_access_token(
        secret_key=secret_key,
        payload={
            "phone_number": phone_number,
            "cyber_name": cyber_name,
        },
        expires_delta=timedelta(hours=24),
    )
    return AuthResponse(token=token, cyber_name=cyber_name)


# ── 接口 1：POST /api/auth/send-key ─────────────────────────
@router.post("/auth/send-key")
async def send_key(
    payload: SendKeyRequest,
    _: None = Depends(content_moderation),
) -> dict:
    """
    向地球维度通讯终端发送跃迁密匙。
    MVP 阶段：密匙打印至后端控制台，前端直接读 log 即可测试。
    """
    await sms_service.send_code(payload.phone_number)
    # 不暴露密匙给前端，只告知"信道已建立"
    return {"ok": True, "message": "跃迁密匙已发送至终端信道"}


# ── 接口 2：POST /api/auth/verify ───────────────────────────
@router.post("/auth/verify", response_model=AuthResponse)
async def verify(
    request: Request,
    payload: VerifyKeyRequest,
    _: None = Depends(content_moderation),
) -> AuthResponse:
    """
    校验跃迁密匙 → 签发 JWT → 分配千禧网名。
    三种失败场景统一返回 400，避免暴露内部状态：
      - 信道不存在（从未发送）
      - 密匙错误
      - 时空窗口已过期（5 分钟）
    """
    # 开发期万能验证码：允许直接用 0000 登录，便于联调
    is_master_code = payload.sms_code == "0000"
    is_valid = is_master_code or await sms_service.verify_code(
        payload.phone_number,
        payload.sms_code,
    )

    if not is_valid:
        # 密匙校验失败 —— 拒绝接入赛博树洞
        raise HTTPException(
            status_code=400,
            detail="invalid_or_expired_code",
        )

    return await _issue_auth_response(request, payload.phone_number)


@router.post("/auth/mobile/verify", response_model=AuthResponse)
async def verify_mobile_login(
    request: Request,
    payload: MobileVerifyRequest,
    _: None = Depends(content_moderation),
) -> AuthResponse:
    """
    无感登录：校验运营商 SDK access_token -> 拿到手机号 -> 签发 JWT。
    """
    phone_number = await mobile_auth_service.verify_access_token(payload.access_token)
    if not phone_number:
        raise HTTPException(status_code=400, detail="invalid_mobile_access_token")
    return await _issue_auth_response(request, phone_number)
