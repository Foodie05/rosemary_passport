# ROSM Passport Flutter SDK 设计

## 目标

`rosm_passport_flutter` 用于让 Flutter 应用以原生界面接入 ROSM Passport，不需要跳转到 Web 登录页，也不包含管理端功能。

SDK 覆盖：

- OIDC Authorization Code + PKCE S256
- `id_token`、`access_token`、`refresh_token`
- `userinfo`
- token refresh
- logout / revoke（public client 可撤销属于自己的 token）
- 邮箱验证码登录
- 手机号验证码登录
- 密码登录
- 密码后的二次验证：邮箱验证码、手机号验证码、TOTP、Passkey
- 独立 Passkey 登录
- 忘记密码：邮箱/手机找回验证码与重置密码
- 登录后添加、列出、删除 Passkey
- SDK 内置 Rosemary 风格登录与授权确认 UI
- 服务端交接模式：把已授权的登录请求交给接入方服务器完成换票和业务会话

## 安全模型

推荐生产应用使用服务端交接模式：

- 不允许在移动端内置 `client_secret`
- 接入方自己的服务器是机密边界，保存 OIDC `client_secret`
- SDK 在 App 内完成登录 UI、授权确认、PKCE 和授权码获取
- SDK 将 `code`、`code_verifier`、`state`、`nonce`、`redirect_uri` 交给接入方服务器
- 接入方服务器调用 `/oidc/token`，校验 `id_token`，再签发自己的 App 会话

Public 直连模式仍可用于轻量应用：

- OIDC client 必须配置为 public
- 使用移动端自定义 scheme redirect URI
- ROSM token 由 SDK 存入平台安全存储，例如 iOS Keychain / Android Keystore

所有模式都必须满足：

- 所有原生授权请求必须使用 PKCE `S256`
- `scope` 包含 `openid` 时必须传 `nonce`
- SDK 在本地生成并校验 `state`、`nonce`、`code_verifier`
- Passkey 走系统能力，不在 SDK 中自行处理私钥
- Passkey 的 relying party 域名必须通过 iOS Associated Domains / Android Digital Asset Links 与应用绑定

## 服务端 Native Bridge

新增接口：

```text
POST /api/v1/oidc/native/start
POST /api/v1/oidc/native/approve
POST /api/v1/oidc/native/cancel
```

这些接口只负责原生授权流程，不复制管理端和登录策略。登录仍复用现有 `/api/v1/auth/*` 能力。

### start

请求：

```json
{
  "client_id": "my_flutter_app",
  "redirect_uri": "com.example.app:/oidc/callback",
  "response_type": "code",
  "scope": "openid profile email phone",
  "state": "generated-state",
  "nonce": "generated-nonce",
  "code_challenge": "pkce-s256-challenge",
  "code_challenge_method": "S256",
  "server_handoff": true
}
```

响应：

```json
{
  "issuer": "https://auth.example.com",
  "authorization_request": {
    "client_id": "my_flutter_app",
    "redirect_uri": "com.example.app:/oidc/callback",
    "response_type": "code",
    "scope": "openid profile email phone",
    "state": "generated-state",
    "nonce": "generated-nonce",
    "code_challenge": "pkce-s256-challenge",
    "code_challenge_method": "S256"
  },
  "client": {
    "client_id": "my_flutter_app",
    "display_name": "Example App",
    "is_official": false,
    "is_confidential": true
  },
  "scopes": [
    {"name": "openid", "description": "确认你的登录身份"},
    {"name": "profile", "description": "基础资料（昵称）"},
    {"name": "email", "description": "电子邮箱"},
    {"name": "phone", "description": "电话号码"}
  ],
  "pkce_required": true,
  "server_handoff": true
}
```

### approve

`approve` 需要当前用户已登录。SDK 可以复用登录接口返回的 `Set-Cookie`，或在后续版本使用专门的 native login token body。

请求体与 `start` 相同。

响应：

```json
{
  "code": "authorization-code",
  "state": "generated-state",
  "redirect_uri": "com.example.app:/oidc/callback",
  "callback_url": "com.example.app:/oidc/callback?code=authorization-code&state=generated-state",
  "client": {
    "client_id": "my_flutter_app",
    "display_name": "Example App",
    "is_official": false
  }
}
```

服务端交接模式下，SDK 不在设备上换 token，而是调用接入方服务器：

```json
{
  "issuer": "https://auth.example.com",
  "client_id": "my_flutter_app",
  "code": "authorization-code",
  "state": "generated-state",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "code_verifier": "original-code-verifier",
  "nonce": "generated-nonce"
}
```

接入方服务器随后调用 `/oidc/token`：

```json
{
  "grant_type": "authorization_code",
  "code": "authorization-code",
  "client_id": "my_flutter_app",
  "client_secret": "server-only-secret",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "code_verifier": "original-code-verifier"
}
```

Public 直连模式下，SDK 可直接调用 `/oidc/token` 并把 token 写入安全存储。

### cancel

请求体与 `start` 相同，响应为 OAuth 标准错误回调信息：

```json
{
  "error": "access_denied",
  "error_description": "The user denied the authorization request.",
  "state": "generated-state",
  "redirect_uri": "com.example.app:/oidc/callback",
  "callback_url": "com.example.app:/oidc/callback?error=access_denied&error_description=The+user+denied+the+authorization+request.&state=generated-state"
}
```

## SDK API 草案

```dart
final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone', 'accountRule'},
  webAuthnOrigin: Uri.parse('https://auth.example.com'),
);

final result = await showRosmPassportSignIn(
  context,
  client: passport,
  config: RosmPassportSignInConfig(
    serverHandoffEndpoint: Uri.parse(
      'https://api.example.com/auth/rosm/sdk/complete',
    ),
    requestCaptchaToken: () => captchaProvider(),
    authenticatePasskey: (options) async {
      final response = await passkeyPlugin.authenticate(options.options);
      return RosmWebAuthnCredential(response);
    },
  ),
);

final appSession = result?.serverPayload;
```

SDK 对应用侧暴露 Dart 类型，例如 `RosmAuthorizationRequest`、`RosmAuthorizationStart`、`RosmAuthResult`、`RosmUserInfo`、`RosmTokenSet`。JSON 编解码只在 SDK 内部完成，模型层使用 `json_serializable` 生成。

忘记密码：

```dart
await passport.sendPasswordRecoveryCode(
  account: 'user@example.com',
  method: RosmPasswordRecoveryMethod.email,
  captchaToken: captchaToken,
);

await passport.resetPasswordByCode(
  account: 'user@example.com',
  method: RosmPasswordRecoveryMethod.email,
  code: '123456',
  newPassword: newPassword,
);
```

通行密钥登录与添加：

```dart
final options = await passport.beginWebAuthnLogin(email: 'user@example.com');
final response = await passkeyPlugin.authenticate(options.options);
await passport.completeWebAuthnLogin(
  email: 'user@example.com',
  credential: RosmWebAuthnCredential(response),
);

final registerOptions = await passport.beginPasskeyRegistration(
  currentPassword: currentPassword,
);
final registerResponse = await passkeyPlugin.register(registerOptions.options);
await passport.completePasskeyRegistration(
  credential: RosmWebAuthnCredential(registerResponse),
);
```

核心类：

- `RosmPassportClient`
- `RosmOidcClient`
- `RosmAuthApi`
- `RosmTokenStore`
- `RosmPasskeyAdapter`
- `RosmCaptchaProvider`

## 接入流程

1. 后台创建或编辑包名式 OIDC client，例如 `com.cruos.zion`。
2. 推荐服务端交接模式：client 配置为 confidential，redirect URI 使用接入方服务器 HTTPS 回调，例如 `https://api.example.com/auth/rosm/callback`，`client_secret` 只保存于接入方服务器。
3. 备用 Public 直连模式：client 配置为 public，redirect URI 使用自定义 scheme，例如 `com.cruos.zion:/oidc/callback`。
3. Flutter 初始化 `RosmPassportClient`。
4. SDK 生成 `state`、`nonce`、PKCE。
5. SDK 调用 `native/start` 获取 client 与 scope 展示信息。
6. 用户选择登录方式并完成登录。
7. SDK 展示原生授权确认。
8. SDK 调用 `native/approve` 获取 authorization code。
9. 服务端交接模式下，SDK 调用接入方服务器 handoff endpoint，服务器带 `client_secret` 和 `code_verifier` 调用 `/oidc/token`。
10. 接入方服务器校验 `state`、`nonce`、`issuer`、`aud`、过期时间和 redirect URI，并签发自己的 App 会话。
11. Public 直连模式下，SDK 可直接调用 `/oidc/token` 并把 refresh token 写入安全存储。

## 后续增强

- 为 auth 登录接口增加可选 `native_client_id`，在响应体中返回一次性 native session token，避免 SDK 依赖 cookie jar。
- `/oidc/token` 同时支持 `application/x-www-form-urlencoded`，增强通用 OIDC 客户端兼容性。
- 增加 Flutter package 与 example app。
- 增加 native bridge 的集成测试。
