# 贡献指南

## 分支与提交

- 从最新 `master` 创建短生命周期分支。自动化改动使用 `codex/<主题>`，人工功能分支建议使用 `feat/<主题>` 或 `fix/<主题>`。
- 一个提交只表达一个可独立审查、可独立回滚的意图；不要混入生成缓存、编辑器状态、秘密或审计输出。
- 提交信息使用 Conventional Commits：`type(scope): summary`。允许的 `type` 为 `feat`、`fix`、`security`、`refactor`、`test`、`docs`、`build`、`ci`、`chore`、`revert`。
- 摘要使用祈使语气，不超过 72 个字符，不以句号结尾。破坏性变化必须在正文使用 `BREAKING CHANGE:`；数据库破坏性变化默认不接受。
- PR 使用 squash merge，PR 标题必须符合相同的提交格式。

示例：

```text
security(auth): revoke refresh family after token replay
test(migrations): preserve legacy authenticator secrets
```

## 数据库变更

- 仅使用 `expand → backfill → validate → contract`，contract 至少推迟一个发布周期。
- 本发布周期不得删除旧列、重命名既有语义或就地重写不可逆历史值。
- 每个迁移必须有固定版本、校验和、事务边界和历史快照兼容测试。
- 回填必须幂等、可分批验证；发布前完成加密备份并验证可读取。

## 本地检查

提交前至少运行：

```bash
./scripts/check_repo_hygiene.sh
./scripts/check_shell_scripts.sh
./scripts/check_commit_messages.sh master HEAD
./ops/tests/remote_deploy_safety_test.sh
./ops/tests/secret_provisioning_test.sh
(cd apps/passport_server && dart format --output=none --set-exit-if-changed lib bin routes test tool && dart run dart_frog_cli:dart_frog build && dart analyze && dart test)
(cd web && npm ci && npm audit --audit-level=high && npm test && npm run build)
(cd packages/rosm_passport_flutter && flutter pub get && dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test)
```

涉及数据库、认证、会话、密钥或部署时，还必须运行 PostgreSQL 集成测试和对应容器冒烟测试。不得通过降低覆盖率、安全扫描或恢复目标来让门禁变绿。

## 代码审查

- 优先检查安全边界、历史数据兼容性、失败模式、并发行为和回滚路径。
- API 变化必须说明兼容期和废弃路径。
- 新日志不得记录 Token、验证码、密码、Cookie、密钥或完整个人敏感信息。
- 新依赖需要说明用途，并通过许可证、漏洞和可维护性检查。
