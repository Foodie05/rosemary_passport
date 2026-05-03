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
