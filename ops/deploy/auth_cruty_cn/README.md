# Rosemary Passport 单机生产部署

本模板用于单机 `SLA-ready` 部署：PostgreSQL、Dart API 和内部身份辅助服务由
Docker Compose 管理，Apache 只代理 `127.0.0.1:8091` 并托管原子切换的前端版本目录。
它不等价于已经具备多节点 99.9% SLA。

## 首次部署

1. 将 `runtime.env.example` 复制到 `/etc/rosm-passport/runtime.env`，只填写非秘密配置。
   `POSTGRES_IMAGE` 和 `NODE_IMAGE` 必须包含已经核验的 `@sha256:` digest。
2. 运行 `sudo ./provision_secrets.sh /etc/rosm-passport/secrets [legacy.env]`。旧环境文件只用于一次性迁移，随后应移出发布目录并安全销毁。
3. 填写 S3 凭据，确保所有秘密文件和目录分别保持 `0400`、`0700`。
4. 为备份桶启用版本控制和至少 30 天的 Object Lock 默认保留策略。部署预检会拒绝未启用版本控制、Object Lock 或保留期不足的桶。仅当对象存储确实不支持 Object Lock 且已有书面风险例外时，才可将 `S3_REQUIRE_OBJECT_LOCK=false`。
5. 执行：

   ```bash
   ./deploy.sh /srv/rosm-passport/current /var/www/auth.cruty.cn \
     /etc/rosm-passport/runtime.env /etc/rosm-passport/secrets
   ```

发布流程固定为预检、加密逻辑与物理备份、构建、兼容迁移、启动、readiness、流量恢复。
前端通过版本目录和软链接原子切换。失败时回滚应用文件；数据库迁移只做 expand，旧应用仍可读取。

默认发布容量预检要求至少 2 个 CPU、4 GiB 物理内存、1 GiB 可用内存与空闲 Swap
合计余量，以及 5 GiB 磁盘余量。生产容量评估确认更高要求时可通过
`ROSM_MIN_*` 环境变量提高门槛，不得为了绕过失败而降低门槛。

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

`pitr_drill.sh` 在独立临时数据目录和独立容器中执行 PITR，不挂载或覆盖生产数据。它写入
专用恢复标记、强制切换 WAL，校验并解密 `physical/latest.json` 指向的基线，通过加密 WAL
恢复到标记之后，核对核心表计数并以 Ed25519 签名证据，最后归档到 S3。每月至少执行一次：

```bash
sudo ROSM_PITR_CONFIRM=isolated-pitr-drill \
  ./pitr_drill.sh /srv/rosm-passport/current \
  /etc/rosm-passport/runtime.env /etc/rosm-passport/secrets
```

只有脚本实测并签名证明 `RPO <= 5 分钟`、`RTO <= 30 分钟` 才能通过恢复门禁。

API、helper 和 PostgreSQL 的受控重启演练使用 `ops/tests/fault_recovery_drill.sh`。脚本要求
显式确认，先创建加密 S3 备份，再逐项重启并将 readiness 恢复耗时写入权限为 `0600` 的
JSONL 证据；应只在已批准的维护窗口或隔离演练环境运行。

## 运维门禁

- 每次发布前执行 CI 的格式、静态分析、单元/集成测试、依赖审计、secret scan、Trivy 和 SBOM。
- 使用 `ops/load/sla_capacity.js` 完成 50 RPS/30 分钟、100 RPS/5 分钟和 500 会话测试。
  默认测试需准备 1,500 组互不复用的 Access/Refresh Token（每个场景的最大 VU 各自隔离）；
  会话文件必须为 `0600`，测试结束后立即销毁，禁止提交到 Git 或归档到 CI 构件。
- 生产发布后每天运行 `record_sla_observation.sh`。脚本检查 live/ready、三项服务、重启计数、
  审计哈希链、物理备份/WAL 新鲜度和磁盘余量；每份记录形成哈希链、Ed25519 签名并归档 S3。
  建议由 root 的 systemd timer/cron 在每天固定 UTC 时间执行：

  ```bash
  ROSM_OBSERVATION_CONFIRM=record-production-sla-evidence \
    ./record_sla_observation.sh /srv/rosm-passport/current \
    /etc/rosm-passport/runtime.env /etc/rosm-passport/secrets \
    /var/lib/rosm-passport/sla-observation
  ```

  第 14 天使用 `./evaluate_sla_observation.sh /var/lib/rosm-passport/sla-observation 14`
  验证日期连续性、签名和哈希链。任一天失败或缺失都必须重新开始完整观察窗口。
- Linux 生产机可在首次部署完成后运行
  `sudo ROSM_SYSTEMD_INSTALL_CONFIRM=install-sla-timers ./install_systemd_units.sh`，安装每日物理备份、
  每小时审计归档和每日 SLA 观察 timer。安装后必须检查 `systemctl list-timers 'rosm-passport-*'`。
- 计划维护窗口不得超过 15 分钟。正式 99.9% SLA 仍需第二应用节点、数据库 HA、负载均衡和外部 SLO 计量。
