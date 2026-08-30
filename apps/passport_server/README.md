# Rosemary Passport Server

## 配置边界

`.env.example` 仅供本地开发。生产发布使用 `ops/deploy/auth_cruty_cn/runtime.env.example` 作为非秘密配置模板，并把所有秘密放入 root-only 文件，通过 `*_FILE` 读取；缺少生产密钥时服务必须 fail closed。

关键配置包括：

- JWT keyring：当前/上一把私钥、公钥和 `kid`，以及独立绑定密钥。
- 数据加密 keyring：当前/上一把 AES-256-GCM 密钥和版本。
- `DB_*`、连接池上下限、获取/语句/锁等待超时。
- `SERVER_BASE_URL`、`WEB_BASE_URL`、可信 Origin 和代理边界。
- SMTP、Captcha、短信及 helper 内部鉴权文件。
- S3/WAL、审计签名和 Refresh JSON 兼容期配置。

生产配置的完整文件名、权限和一次性旧环境迁移流程见 `ops/deploy/auth_cruty_cn/README.md`。

## 生命周期

生产二进制启动前运行版本化迁移器。迁移由 PostgreSQL advisory lock 串行化，校验和不一致或迁移失败会阻止服务启动；本发布周期只允许向后兼容的 expand/backfill/validate 变化。

健康检查：

- `GET /health/live`：进程存活，不访问依赖。
- `GET /health/ready`：检查数据库、迁移版本和内部 helper。

## 主要接口

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET|PATCH /api/v1/me`
- `GET /api/v1/admin/users`
- `PATCH /api/v1/admin/users/:id/roles`
- `GET /api/v1/admin/audits`
- OIDC：`/oidc/authorize`、`/oidc/token`、`/oidc/userinfo`、`/oidc/jwks`、`/oidc/introspect`、`/oidc/revoke`

机密 OIDC 客户端的 `client_secret` 由服务端生成，只在创建或轮换响应中返回一次，并使用 `Cache-Control: no-store`；数据库只保存 Argon2id 哈希。生产 `SERVER_BASE_URL` 与 `WEB_BASE_URL` 必须为 HTTPS。

## 验证

```bash
dart pub get
dart format --output=none --set-exit-if-changed lib bin routes test tool
dart run dart_frog_cli:dart_frog build
dart analyze --fatal-infos
dart --branch-coverage run test --concurrency=1 --coverage-path=coverage/lcov.info --branch-coverage
dart run tool/check_coverage.dart coverage/lcov.info
npm ci
npm audit --audit-level=high
```
