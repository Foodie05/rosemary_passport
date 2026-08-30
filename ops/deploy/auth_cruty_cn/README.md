# Rosemary Passport 单机生产部署

本模板用于单机 `SLA-ready` 部署：PostgreSQL、Dart API 和内部身份辅助服务由
Docker Compose 管理，Apache 只代理 `127.0.0.1:8091` 并托管原子切换的前端版本目录。
它不等价于已经具备多节点 99.9% SLA。

## 首次部署

1. 将 `runtime.env.example` 复制到 `/etc/rosm-passport/runtime.env`，只填写非秘密配置。
   `POSTGRES_IMAGE` 和 `NODE_IMAGE` 必须包含已经核验的 `@sha256:` digest。
2. 运行 `sudo ./provision_secrets.sh /etc/rosm-passport/secrets [legacy.env]`。旧环境文件只用于一次性迁移，随后应移出发布目录并安全销毁。
3. 填写 S3 凭据，确保所有秘密文件和目录分别保持 `0400`、`0700`。
4. 为备份桶启用版本控制；对象存储支持时启用 Object Lock/不可变保留策略。部署预检会拒绝未启用版本控制的桶。
5. 执行：

   ```bash
   ./deploy.sh /srv/rosm-passport/current /var/www/auth.cruty.cn \
     /etc/rosm-passport/runtime.env /etc/rosm-passport/secrets
   ```

发布流程固定为预检、加密逻辑与物理备份、构建、兼容迁移、启动、readiness、流量恢复。
前端通过版本目录和软链接原子切换。失败时回滚应用文件；数据库迁移只做 expand，旧应用仍可读取。

## 健康检查与秘密轮换

- 存活：`GET /health/live`
- 就绪：`GET /health/ready`（数据库、迁移版本和 helper 都必须正常）
- JWT 轮换：生成新的 `<kid>.private.pem` / `<kid>.public.pem`，先加入 keyring，再修改
  `JWT_ACTIVE_KID`。至少保留上一把公钥至所有旧令牌过期后再移除。
- 数据密钥轮换：加入新的 `<kid>.key` 并修改 `DATA_ENCRYPTION_ACTIVE_KID`；旧密钥必须保留，直到完成受控重加密和抽样解密验证。
- `LEGACY_JSON_REFRESH_SUNSET_AT` 在首次加固发布时一次性设置为该发布时间加 14 天；
  不得滚动延后。到期后 JSON Refresh Token 自动拒绝，Refresh Cookie 不受影响。

## 备份、审计与恢复

- `archive_timeout=300s`，WAL 加密后连续写入 `s3://BUCKET/wal/`。
- `backup_to_s3.sh` 创建可逐表恢复的加密逻辑备份。
- `physical_backup_to_s3.sh` 创建含起始 WAL 的加密物理基线，用于 PITR。
- `archive_audit_to_s3.sh` 导出哈希链审计日志，以 Ed25519 签名并上传 S3。建议每小时执行。
- `restore_from_s3.sh` 只恢复到新的数据库名，必须用 `ROSM_RESTORE_CONFIRM` 明确确认，不会覆盖当前数据库。

PITR 演练必须在隔离主机进行：下载 `physical/latest.json` 指向的基线并校验 SHA-256，
解密到空的 PostgreSQL 数据目录；配置 `restore_command` 从 `wal/` 下载并解密 WAL，设置
`recovery_target_time` 后创建 `recovery.signal`。恢复启动后执行一致性核对与应用冒烟测试。
每月至少演练一次并记录：最后已归档 WAL 时间、目标恢复时间、服务恢复时间。只有实测
`RPO <= 5 分钟` 且 `RTO <= 30 分钟` 才能通过发布门禁。

API、helper 和 PostgreSQL 的受控重启演练使用 `ops/tests/fault_recovery_drill.sh`。脚本要求
显式确认，先创建加密 S3 备份，再逐项重启并将 readiness 恢复耗时写入权限为 `0600` 的
JSONL 证据；应只在已批准的维护窗口或隔离演练环境运行。

## 运维门禁

- 每次发布前执行 CI 的格式、静态分析、单元/集成测试、依赖审计、secret scan、Trivy 和 SBOM。
- 使用 `ops/load/sla_capacity.js` 完成 50 RPS/30 分钟、100 RPS/5 分钟和 500 会话测试。
  默认测试需准备 1,500 组互不复用的 Access/Refresh Token（每个场景的最大 VU 各自隔离）；
  会话文件必须为 `0600`，测试结束后立即销毁，禁止提交到 Git 或归档到 CI 构件。
- 生产发布后进行 14 天观察：不得出现崩溃循环、迁移失败、备份失败或 high/critical 可达漏洞。
- 计划维护窗口不得超过 15 分钟。正式 99.9% SLA 仍需第二应用节点、数据库 HA、负载均衡和外部 SLO 计量。
