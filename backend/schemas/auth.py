from __future__ import annotations

from pydantic import BaseModel, Field


class SendKeyRequest(BaseModel):
    # 地球维度通讯终端号（手机号）
    phone_number: str = Field(min_length=6, max_length=32)


class VerifyKeyRequest(BaseModel):
    # 再次携带终端号 + 跃迁密匙
    phone_number: str = Field(min_length=6, max_length=32)
    sms_code: str = Field(min_length=4, max_length=8)


class AuthResponse(BaseModel):
    # JWT 访问令牌 + 系统分配的千禧网名
    token: str
    cyber_name: str


class ForgeIdentityPreviewResponse(BaseModel):
    # 预生成候选昵称 + 剩余可生成次数
    cyber_name: str
    remaining_attempts: int


class ForgeIdentitySaveRequest(BaseModel):
    # 用户在弹窗中选定并提交保存的昵称
    cyber_name: str = Field(min_length=1, max_length=128)


class MobileVerifyRequest(BaseModel):
    # 运营商一键登录 SDK 返回的授权 token
    access_token: str = Field(min_length=6, max_length=2048)
