# ROSM Passport OIDC 接入文档

## 1. 结论先看

当前实现可以支持以下核心能力：

- Discovery 文档发布
- 授权码模式
- PKCE `S256`
- `refresh_token`
- `userinfo`
- `jwks`
- `introspect`
- `revoke`
- RS256 签名 JWT

但它**还不是严格意义上完整符合 OpenID Connect Core 的标准 OIDC 实现**。  
更准确地说，它目前是一个“可用的 OIDC 风格授权服务器”，适合自控客户端接入，但如果要对接严格依赖标准 OIDC 细节的第三方 SDK、网关或 SaaS，仍有兼容风险。

## 2. 已实现的规范能力

### 2.1 Discovery

服务端已发布：

- `GET /.well-known/openid-configuration`

返回内容包含：

- `issuer`
- `authorization_endpoint`
- `token_endpoint`
- `userinfo_endpoint`
- `jwks_uri`
- `revocation_endpoint`
- `introspection_endpoint`
- `response_types_supported`
- `subject_types_supported`
- `id_token_signing_alg_values_supported`
- `token_endpoint_auth_methods_supported`
- `code_challenge_methods_supported`
- `grant_types_supported`
- `scopes_supported`

对应实现：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/.well-known/openid-configuration.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/.well-known/openid-configuration.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart)

### 2.2 授权码模式

已实现：

- `GET /oidc/authorize`
- `POST /oidc/token`

能力特点：

- 校验 `client_id`
- 校验 `redirect_uri`
- 校验客户端允许的 `scope`
- 校验客户端允许的 `grant_type`
- 当 `scope` 包含 `openid` 时，要求请求携带非空 `nonce`
- 默认支持 `authorization_code`
- 支持 PKCE `S256`
- 授权码一次性消费
- 授权码 10 分钟有效

对应实现：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/authorize.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/authorize.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/token.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/token.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/repositories/oidc_repository.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/repositories/oidc_repository.dart)

### 2.3 JWT 与 JWKS

当前令牌签名使用：

- `RS256`
- 固定 `kid = rosm-signing-v1`

已发布：

- `GET /oidc/jwks`

对应实现：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/jwks.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/jwks.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/security/token_service.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/security/token_service.dart)

### 2.4 UserInfo

已实现：

- `GET /oidc/userinfo`

认证方式：

- `Authorization: Bearer <access_token>`

当前返回字段（按 scope 决定）：

- `sub`
- `email`（需要 `email` scope）
- `nickname`（需要 `profile` scope）
- `roles`（需要 `accountRule` scope）

对应实现：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/userinfo.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/userinfo.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart)

### 2.5 Introspect 与 Revoke

已实现：

- `POST /oidc/introspect`
- `POST /oidc/revoke`

特点：

- `introspect` 仅允许机密客户端
- `revoke` 仅允许机密客户端
- `refresh_token` 会落库，可检查是否被撤销
- `introspect` 可检查 access token 与 refresh token

对应实现：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/introspect.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/introspect.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/revoke.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/revoke.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart)

## 3. 目前不符合或偏离标准的地方

这一节最重要。

### 3.1 缺少 `id_token`

这是当前实现距离“标准 OIDC”最大的差距。

问题：

- Discovery 声明了 `id_token_signing_alg_values_supported`
- 但 `token` 端点返回只有：
  - `access_token`
  - `refresh_token`
  - `token_type`
  - `expires_in`
- **没有 `id_token`**

这意味着：

- 它更像 OAuth 2.0 + UserInfo 的组合
- 很多标准 OIDC Client/SDK 在收到 token 响应时会期待 `id_token`
- 严格 OIDC RP 往往无法按标准方式完成登录态建立

证据：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/security/token_service.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/security/token_service.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/services/oidc_service.dart)

### 3.2 `/oidc/authorize` 已显式校验 `response_type=code`

Discovery 声明：

- `response_types_supported = ["code"]`

授权端点当前会显式校验请求里必须满足：

- `response_type=code`

若不满足会直接返回 `400 access_denied`，避免错误客户端“误通过”。

### 3.3 `nonce` 行为（当前实现）

标准 OIDC 中，尤其在需要 `id_token` 的流程里，`nonce` 很关键。当前实现：

- 已接收 `nonce`，并在授权码记录中存储 `nonce`
- 当请求 `scope` 包含 `openid` 时，必须携带非空 `nonce`，否则 `/oidc/authorize` 会直接 `400 access_denied`
- 但当前 `token` 响应仍不返回 `id_token`，因此还没有 `id_token` 中的 `nonce` 回传链路

所以接入方现在必须遵守：`scope` 含 `openid` 必传 `nonce`；同时如果未来补齐标准 OIDC，仍需配合 `id_token` 完整验证流程。

### 3.4 `token / introspect / revoke` 只接受 JSON，不接受标准表单编码

当前路由统一使用 JSON body：

- `application/json`

但相关 RFC 约定里，这些端点通常使用：

- `application/x-www-form-urlencoded`

这会导致：

- 很多标准 OIDC/OAuth 客户端库直接对接会失败
- 需要额外自定义请求适配

对应路由：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/token.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/token.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/introspect.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/introspect.dart)
- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/revoke.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/routes/oidc/revoke.dart)

### 3.5 不支持 `client_secret_basic`

Discovery 当前声明：

- `token_endpoint_auth_methods_supported = ["client_secret_post", "none"]`

这与实现一致，但问题是：

- 只支持 body 中传 `client_secret`
- 不支持很多客户端默认使用的 `Authorization: Basic ...`

这不算“实现和 discovery 不一致”，但会限制兼容性。

### 3.6 UserInfo 返回的是项目自定义字段，不是更标准的 claims 命名

当前返回：

- `nickname`
- `roles`

而更常见的 OIDC claims 会是：

- `name`
- `preferred_username`
- `given_name`
- `family_name`

这不一定错误，但会影响通用客户端的即插即用能力。

### 3.7 `userinfo` 只支持 GET

标准上很多实现同时支持：

- `GET /userinfo`
- `POST /userinfo`

当前只支持 GET。多数情况下够用，但兼容性不是最优。

### 3.8 `issuer` 与 JWT `iss` 可能不一致

Discovery 中 `issuer` 来自：

- `SERVER_BASE_URL`

JWT 中 `iss` 来自：

- `JWT_ISSUER`

如果部署时这两个环境变量没有保持一致，就会出现：

- discovery 说的 issuer 是 A
- token 实际签发的 `iss` 是 B

这对标准 OIDC 客户端是致命问题。

对应配置：

- [/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/config/app_config.dart](/Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server/lib/src/config/app_config.dart)

## 4. 规范符合性判断

### 4.1 如果按“是否符合完整 OIDC Core”来判断

结论：

- **目前不完全符合**

核心原因：

- 缺少 `id_token`
- 缺少 `nonce`
- token 相关端点未使用标准表单编码

### 4.2 如果按“是否可作为受控环境内的 OIDC 风格接入服务”来判断

结论：

- **可以使用**

适用场景：

- 自家前后端
- 自己控制的接入应用
- 可以按本文档手工适配请求格式的服务

不建议直接宣称“标准 OIDC Fully Compliant”，也不建议直接对接要求严格标准兼容的第三方平台。

## 5. 当前实现下的接入方式

本节按“现状可接入”的方式来写，和严格标准 SDK 的默认行为可能不完全一致。

### 5.1 先在后台创建客户端

后台路径：

- 管理后台 -> OIDC 接入

需要配置：

- `Client ID`
- `Client Secret`
- `Redirect URIs`
- `Scopes`
- `Grant Types`
- `is_confidential`
- `is_active`

推荐配置：

- `scopes`
  - `openid`
  - `profile`
  - `email`
  - `accountRule`（如需让应用识别账号角色：admin/user）
- `grant_types`
  - `authorization_code`
  - `refresh_token`

说明：

- 机密客户端必须配置 `client_secret`
- 公共客户端可以不配 `client_secret`
- 当前服务默认要求 PKCE `S256`

### 5.2 读取 Discovery

请求：

```bash
curl https://your-passport.example.com/.well-known/openid-configuration
```

重点读取字段：

- `issuer`
- `authorization_endpoint`
- `token_endpoint`
- `userinfo_endpoint`
- `jwks_uri`
- `revocation_endpoint`
- `introspection_endpoint`
- `scopes_supported`（当前为 `openid`、`profile`、`email`、`accountRule`）

### 5.3 发起授权请求

当前服务使用：

- 已登录用户态访问 `GET /oidc/authorize`
- 未登录会 `302` 跳转到登录页（`/login?next=...`）
- 不会自动拉起单独的 Hosted Login UI

示例：

```text
GET /oidc/authorize
  ?response_type=code
  ?client_id=my-client
  &redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback
  &scope=openid%20profile%20email
  &state=abc123
  &nonce=nonce-abc123
  &code_challenge=BASE64URL_SHA256
  &code_challenge_method=S256
```

成功后会 `302` 跳转到：

```text
https://app.example.com/callback?code=xxx&state=abc123
```

说明：

- 当前实现会显式校验 `response_type=code`
- 当 `scope` 包含 `openid` 时，`nonce` 为必填

建议完整请求参数：

- `response_type=code`
- `client_id`
- `redirect_uri`
- `scope`
- `state`
- `nonce`（当 `scope` 包含 `openid` 时必填）
- `code_challenge`
- `code_challenge_method=S256`

### 5.4 用授权码换取令牌

注意：**当前 token 端点要求 JSON body，不是表单编码。**

请求示例：

```bash
curl -X POST https://your-passport.example.com/oidc/token \
  -H 'Content-Type: application/json' \
  -d '{
    "grant_type": "authorization_code",
    "code": "AUTH_CODE",
    "client_id": "my-client",
    "client_secret": "my-secret",
    "redirect_uri": "https://app.example.com/callback",
    "code_verifier": "ORIGINAL_CODE_VERIFIER"
  }'
```

返回示例：

```json
{
  "access_token": "xxx",
  "refresh_token": "yyy",
  "token_type": "Bearer",
  "expires_in": 900
}
```

注意：

- 当前**不会返回 `id_token`**

### 5.5 获取用户信息

请求：

```bash
curl https://your-passport.example.com/oidc/userinfo \
  -H 'Authorization: Bearer ACCESS_TOKEN'
```

返回示例：

```json
{
  "sub": "user-id",
  "email": "user@example.com",
  "nickname": "Alpaca",
  "roles": ["user", "admin"]
}
```

说明：

- `roles` 仅在申请了 `accountRule` scope 时返回。

### 5.6 刷新令牌

请求示例：

```bash
curl -X POST https://your-passport.example.com/oidc/token \
  -H 'Content-Type: application/json' \
  -d '{
    "grant_type": "refresh_token",
    "refresh_token": "REFRESH_TOKEN",
    "client_id": "my-client",
    "client_secret": "my-secret"
  }'
```

### 5.7 Introspect

仅机密客户端可用。

请求示例：

```bash
curl -X POST https://your-passport.example.com/oidc/introspect \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "TOKEN_TO_CHECK",
    "client_id": "my-client",
    "client_secret": "my-secret"
  }'
```

返回可能类似：

```json
{
  "active": true,
  "sub": "user-id",
  "scope": "openid profile email accountRule",
  "token_type": "access_token"
}
```

或：

```json
{
  "active": false
}
```

### 5.8 Revoke

仅机密客户端可用。

请求示例：

```bash
curl -X POST https://your-passport.example.com/oidc/revoke \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "REFRESH_TOKEN",
    "client_id": "my-client",
    "client_secret": "my-secret"
  }'
```

返回示例：

```json
{
  "revoked": true
}
```

## 6. 建议的接入策略

### 6.1 如果你是自家应用

推荐：

- 按本文档直接接
- 不强依赖标准 OIDC SDK 自动流程
- 自己控制 token 请求格式为 JSON
- 登录完成后以 `access_token + userinfo` 建立会话

### 6.2 如果你要接第三方标准 OIDC 客户端

建议先补齐以下能力后再对外：

- `id_token`
- `nonce`
- `response_type=code` 严格校验
- `application/x-www-form-urlencoded` 解析
- `client_secret_basic`
- 更标准的 claims
- `issuer` 与 JWT `iss` 强一致

## 7. 上线前检查清单

- `SERVER_BASE_URL` 与对外访问域名一致
- `JWT_ISSUER` 与 discovery 中的 `issuer` 保持一致
- `JWT_AUDIENCE` 已与接入方约定
- RSA 公私钥已正确配置
- `OIDC_REQUIRE_PKCE=true`
- 客户端 `redirect_uri` 已精确登记
- 机密客户端已设置 `client_secret`
- 生产环境已验证 `/.well-known/openid-configuration`
- 生产环境已验证 `/oidc/jwks`

## 8. 建议的后续改造优先级

按优先级从高到低：

1. 补 `id_token`，并在 `authorization_code` 流程中返回
2. 在补齐 `id_token` 后，完善 `nonce` 的标准回传与校验链路
3. 将 `token / introspect / revoke` 改为兼容 `application/x-www-form-urlencoded`
4. 支持 `client_secret_basic`
5. 统一 `issuer` 与 JWT `iss`
6. 增加标准 claims，例如 `name`、`preferred_username`
7. 视需要支持 `POST /userinfo`

## 9. 文档适用范围

本文档描述的是**当前仓库里的实际实现行为**，不是对理想标准形态的假设。  
如果后续补了 `id_token`、表单编码和标准客户端认证方式，这份文档也需要同步更新。
