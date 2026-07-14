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
- 原生授权确认

## 安全模型

Flutter 应用只能作为 public client 接入：

- 不允许在移动端内置 `client_secret`
- 所有原生授权请求必须使用 PKCE `S256`
- `scope` 包含 `openid` 时必须传 `nonce`
- SDK 在本地生成并校验 `state`、`nonce`、`code_verifier`
- refresh token 存入平台安全存储，例如 iOS Keychain / Android Keystore
- Passkey 走系统能力，不在 SDK 中自行处理私钥

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
  "code_challenge_method": "S256"
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
    "is_official": false
  },
  "scopes": [
    {"name": "openid", "description": "确认你的登录身份"},
    {"name": "profile", "description": "基础资料（昵称）"},
    {"name": "email", "description": "电子邮箱"},
    {"name": "phone", "description": "电话号码"}
  ],
  "pkce_required": true
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

SDK 随后调用 `/oidc/token`：

```json
{
  "grant_type": "authorization_code",
  "code": "authorization-code",
  "client_id": "my_flutter_app",
  "redirect_uri": "com.example.app:/oidc/callback",
  "code_verifier": "original-code-verifier"
}
```

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
  clientId: 'my_flutter_app',
  redirectUri: Uri.parse('com.example.app:/oidc/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone'},
);

final result = await passport.signInWithEmailCode(
  email: 'user@example.com',
  codeProvider: (challenge) async {
    await challenge.send();
    return showCodeInput();
  },
);

final user = await passport.userInfo();
await passport.refresh();
await passport.signOut();
```

SDK 对应用侧暴露 Dart 类型，例如 `RosmAuthorizationRequest`、`RosmAuthorizationStart`、`RosmAuthResult`、`RosmUserInfo`、`RosmTokenSet`。JSON 编解码只在 SDK 内部完成，模型层使用 `json_serializable` 生成。

核心类：

- `RosmPassportClient`
- `RosmOidcClient`
- `RosmAuthApi`
- `RosmTokenStore`
- `RosmPasskeyAdapter`
- `RosmCaptchaProvider`

## 接入流程

1. 后台创建 OIDC public client。
2. 配置 native redirect URI，例如 `com.example.app:/oidc/callback`。
3. Flutter 初始化 `RosmPassportClient`。
4. SDK 生成 `state`、`nonce`、PKCE。
5. SDK 调用 `native/start` 获取 client 与 scope 展示信息。
6. 用户选择登录方式并完成登录。
7. SDK 展示原生授权确认。
8. SDK 调用 `native/approve` 获取 authorization code。
9. SDK 调用 `/oidc/token` 换取 token。
10. SDK 校验 `state`、`nonce`、`id_token` 关键 claims。
11. SDK 将 refresh token 写入安全存储。

## 后续增强

- 为 auth 登录接口增加可选 `native_client_id`，在响应体中返回一次性 native session token，避免 SDK 依赖 cookie jar。
- `/oidc/token` 同时支持 `application/x-www-form-urlencoded`，增强通用 OIDC 客户端兼容性。
- 增加 Flutter package 与 example app。
- 增加 native bridge 的集成测试。
