# Rosemary Passport

Rosemary Passport 是面向多应用接入的身份与单点登录服务。服务端基于 Dart Frog 和 PostgreSQL，包含标准 OIDC、WebAuthn/Passkey、用户中心、管理后台及 Flutter 接入包。

## 安全与兼容能力

- 密码使用 Argon2id，新增或修改密码执行 12-128 字符及泄露密码策略；历史密码仍可登录。
- Access Token 固定为 15 分钟；Refresh Token 使用 family、单次轮换、重放检测和整族撤销。
- 第一方刷新使用 `HttpOnly`、`Secure`、`SameSite` Cookie，并校验可信 Origin。
- JWT 使用带 `kid` 的多密钥环；JWKS 可同时发布当前与上一把公钥。
- WebAuthn 管理员及新凭据强制用户验证，普通用户迁移期由数据库字段控制。
- OIDC 支持 Authorization Code、PKCE、表单编码 Token/撤销/内省及 JSON 兼容。
- 敏感系统设置使用版本化 AES-256-GCM 信封加密，并兼容历史明文行的受控回填。
- 数据库迁移具有版本、校验和、事务和 PostgreSQL advisory lock；采用 expand/backfill/validate，禁止本周期破坏旧列。
- 生产容器非 root、只读根文件系统、最小权限并提供 `/health/live` 与 `/health/ready`。

代码通过仓库卫生、服务端测试、Web、Flutter、供应链和 CodeQL 六项默认分支门禁。绿色 CI 只证明代码候选满足工程门禁；正式生产 SLA 仍必须完成容量、PITR 和稳定观察验收。

## 仓库结构

- `apps/passport_server/`：Dart Frog 服务端、迁移器和 Node helper。
- `web/`：React/Vite 第一方 Web 应用。
- `packages/rosm_passport_flutter/`：Flutter 接入包。
- `ops/postgres/`：兼容初始化快照。
- `ops/deploy/auth_cruty_cn/`：生产部署、备份、WAL、PITR 与观察脚本。
- `ops/load/`：50 RPS、100 RPS 突发和 500 并发会话容量门禁。

## 本地开发

macOS 开发环境可运行：

```bash
./run_local.sh
```

脚本启动本地 PostgreSQL、执行兼容迁移，并分别启动后端与 Web。仅首次创建的本地管理员凭据保存在 `.local/admin_credentials.env`；`.local/` 权限为 `0700`，凭据和本地 `.env` 权限为 `0600`，密码不会回显到终端。

停止本地服务：

```bash
./stop_local.sh
```

本地 `.env` 只用于开发且被 Git 忽略。生产环境禁止复制该文件，必须使用 `/etc/rosm-passport/runtime.env` 的非秘密配置和 `/etc/rosm-passport/secrets/` 下的 root-only `*_FILE` 密钥。

## 质量门禁

提交前至少运行：

```bash
./scripts/check_repo_hygiene.sh
./scripts/check_commit_messages.sh master HEAD
(cd web && npm ci && npm audit --audit-level=high && npm test && npm run build)
(cd packages/rosm_passport_flutter && flutter pub get && flutter analyze && flutter test)
(cd apps/passport_server && dart pub get && dart analyze && dart test)
```

完整 CI 还执行 PostgreSQL 集成测试、覆盖率门禁、gitleaks、SBOM、Trivy 文件系统/容器扫描和 CodeQL `security-extended`。

## 生产部署

不要直接在生产主机运行开发脚本或手工执行初始化 SQL。按照 `ops/deploy/auth_cruty_cn/README.md` 完成：

1. 主机容量和磁盘预检。
2. S3 版本控制/Object Lock 能力检查及加密备份确认。
3. 不可变镜像构建和维护模式切换。
4. 向后兼容迁移、readiness 与冒烟测试。
5. 独立 PITR 演练、容量门禁及 14 天签名观察。

单机完成这些门禁后只能标记为 `SLA-ready`；99.9% SLA 还需要第二应用节点、PostgreSQL 高可用、负载均衡和外部 SLI/SLO 计量。

## 安全报告

发现漏洞时请遵循 [SECURITY.md](SECURITY.md)，使用 GitHub 私有漏洞报告，不要在公开 Issue 中披露利用细节、凭据或个人数据。

贡献、数据库兼容和提交规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。
