# 协议、账户处置与行为日志

## 协议版本

- `terms` 与 `privacy` 分别维护独立、单调递增的版本号。
- 每种协议最多存在一个草稿；保存草稿不会影响线上用户。
- 发布操作不可覆盖历史版本。公开接口始终返回版本号最高的已发布版本。
- 注册和每次完成登录时，客户端必须提交 `accepted_legal=true`、`terms_version` 与 `privacy_version`。服务端只接受当前发布组合，并保存版本绑定的接受证据。
- Web 阅读页为 `/legal/terms` 与 `/legal/privacy`；API 为 `GET /api/v1/legal/documents`。

## 管理边界

`/api/v1/admin/dashboard`、`/api/v1/admin/legal/**` 和 `/api/v1/admin/users/**` 均位于 `requireAdmin` 中间件之后。前端也会阻止普通用户进入 `/admin`，但前端控制不作为安全边界。

管理员封禁用户时必须记录原因。系统会立即撤销该用户全部 Access Token 与 Refresh Token family；刷新、OIDC 授权、UserInfo、Token Introspection 和新的登录都会再次查询账户状态并 fail closed。解封不会恢复旧会话。

## 数据最小化

- `activity_logs` 不保存请求体、密码、验证码、Cookie、Token 或客户端密钥。
- 路径中的 UUID 和数字标识会归一化，IP 与 User-Agent 使用服务端密钥 HMAC 化。
- 新写入的哈希链审计日志会掩码邮箱并 HMAC 化 IP；历史记录保持原样，以免破坏既有哈希链。
- 看板仅返回聚合后的按日计数。邮箱指标表示验证码记录创建/发放尝试，不代表邮件服务商最终投递成功。

## 数据库兼容性

迁移只扩展 `users`，并新增 `legal_documents`、`user_legal_acceptances` 与 `activity_logs`。旧用户自动为 `active`；本轮不删除或重解释任何历史列。旧应用可忽略新增列并继续运行。

