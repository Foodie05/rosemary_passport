# ROSM Passport Server

## 环境变量

参考同目录 `.env.example`。

关键项：

- `JWT_PRIVATE_KEY_PEM` / `JWT_PUBLIC_KEY_PEM`
- `JWT_BINDING_KEY`（双Key中的第二把Key）
- `HCAPTCHA_SECRET`（兼容旧键：`TURNSTILE_SECRET`）
- `DB_*`

## 主要 API

- `POST /api/v1/auth/send-code`
- `POST /api/v1/auth/send-phone-code`
- `POST /api/v1/auth/verify-phone-code`
- `POST /api/v1/auth/admin-login-code`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET|PATCH /api/v1/me`
- `GET /api/v1/admin/users`
- `PATCH /api/v1/admin/users/:id/roles`
- `GET /api/v1/admin/audits`
- OIDC:
  - `GET /.well-known/openid-configuration`
  - `GET /oidc/authorize`
  - `POST /oidc/token`
  - `GET /oidc/userinfo`
  - `GET /oidc/jwks`
  - `POST /oidc/introspect`
  - `POST /oidc/revoke`

## 手机号验证码（阿里云号码认证）

需配置以下环境变量后自动启用：

- `ALIYUN_ACCESS_KEY_ID`
- `ALIYUN_ACCESS_KEY_SECRET`
- `ALIYUN_SMS_SIGN_NAME`
- `ALIYUN_SMS_TEMPLATE_CODE`

可选项：

- `ALIYUN_SMS_SCHEME_NAME`
- `ALIYUN_SMS_COUNTRY_CODE`（默认 `86`）
- `ALIYUN_SMS_CODE_LENGTH`（默认 `6`）
- `ALIYUN_SMS_VALID_TIME_SECONDS`（默认 `300`）
- `ALIYUN_SMS_SEND_INTERVAL_SECONDS`（默认 `60`）
- `ALIYUN_SMS_DUPLICATE_POLICY`（默认 `1`，覆盖旧验证码）

接口：

- `POST /api/v1/auth/send-phone-code`
  - body: `{ "phone_number": "13800138000", "country_code": "86", "captcha_token": "..." }`
- `POST /api/v1/auth/verify-phone-code`
  - body: `{ "phone_number": "13800138000", "country_code": "86", "verify_code": "123456" }`
