# rosm_passport_flutter

Flutter SDK for ROSM Passport native sign-in. The SDK includes a Rosemary-style sign-in UI and also exposes typed Dart APIs for apps that need custom screens.

The recommended production mode is server handoff:

- The Flutter app never ships `client_secret`.
- The app server owns the confidential OIDC client.
- The SDK signs the user in inside the app, obtains an authorization code with PKCE, and posts the code plus `code_verifier` to the app server.
- The app server exchanges the code at ROSM Passport with its `client_secret`, validates the OIDC result, creates its own app session, and returns that session payload to Flutter.

## Add the dependency

```yaml
dependencies:
  rosm_passport_flutter:
    git:
      url: https://github.com/Foodie05/rosemary_passport.git
      ref: v0.7.0
      path: packages/rosm_passport_flutter
```

## Recommended: built-in UI with server handoff

Register a confidential OIDC client in ROSM Passport. Use a package-style `client_id`, for example `com.cruos.zion`, but register the redirect URI as your app server HTTPS callback, for example `https://api.example.com/auth/rosm/callback`. Keep `client_secret` only on that server.

```dart
final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone', 'accountRule'},
);

final result = await showRosmPassportSignIn(
  context,
  client: passport,
  config: RosmPassportSignInConfig(
    serverHandoffEndpoint: Uri.parse('https://api.example.com/auth/rosm/sdk/complete'),
    enableRegistration: true,
  ),
);

final appSession = result?.serverPayload;
```

The built-in UI supports email code login, phone code login, password login, password MFA, password recovery, email registration, and the final consent page. Registration is enabled by default. Set `enableRegistration: false` if an app wants to hide account creation.

The built-in sign-in and account-management screens follow the device appearance by default. They use the same sage-based ROSM Pass visual language in both light and dark mode. An app can explicitly select an appearance when needed:

```dart
const signInConfig = RosmPassportSignInConfig(
  themeMode: RosmPassportThemeMode.dark,
);

const accountConfig = RosmPassportAccountConfig(
  themeMode: RosmPassportThemeMode.dark,
  signInConfig: signInConfig,
);
```

Available values are `system`, `light`, and `dark`. Input text and controls always use contrast-safe colors from the selected ROSM Passport color scheme rather than inheriting potentially incompatible colors from the host application.

The SDK uses ROSM's public configuration to run the built-in Aliyun Captcha 2.0 challenge before sending a login, registration, recovery, or MFA code. It sends the returned `captchaVerifyParam` as `captcha_token`; apps do not provide or store Aliyun credentials. To use an existing in-app captcha implementation instead, supply `requestCaptchaToken`; its non-empty return value takes precedence.

After a successful email-code, phone-code, or password login, the SDK securely stores only the selected method and its email address or phone number. The next built-in sign-in screen uses these values to preselect the method and prefill the identifier; it still always requires a new authentication. Call `client.clearLastSignIn()` if the app needs to remove this convenience data. `client.signOut()` clears it as well.

In public direct mode, access-token expiry is handled with the stored refresh token. Concurrent unauthorized requests share one refresh operation so a rotating refresh token is never submitted twice by the SDK.

Opening the built-in account center always starts a fresh ROSM verification. If the ROSM session expires while the page is open, it presents the same verification again. Both flows use the saved, non-secret sign-in hint only for method selection and identifier prefill.

## Logging and debugging

The SDK exposes four log levels: `debug`, `info`, `warning`, and `error`. Logging is disabled by default. Apps can enable console output, or forward structured records to their own logging service.

```dart
RosmPassportLogging.configure(
  RosmPassportLogger.console(
    minLevel: RosmLogLevel.debug,
    sinks: [
      (record) {
        yourLoggingService.write(record.toJson());
      },
    ],
  ),
);

final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
);
```

For per-client routing, pass a logger directly:

```dart
final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
  logger: RosmPassportLogger(
    minLevel: RosmLogLevel.info,
    sinks: [(record) => yourLoggingService.write(record.toJson())],
  ),
);
```

HTTP logs intentionally include only method, path, status code, duration, and error code. They do not record passwords, captcha tokens, authorization codes, or other credentials.

The server handoff endpoint receives a JSON body generated by the SDK:

```json
{
  "issuer": "https://auth.example.com",
  "client_id": "com.cruos.zion",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "code": "AUTHORIZATION_CODE",
  "state": "STATE",
  "callback_url": "https://api.example.com/auth/rosm/callback?code=...",
  "code_verifier": "ORIGINAL_PKCE_VERIFIER",
  "scope": "openid profile email phone accountRule",
  "nonce": "NONCE",
  "extra": {}
}
```

Your server should verify its own login challenge or session binding, exchange the code at `/oidc/token` with `client_secret` and `code_verifier`, validate the ID token nonce and issuer, create the app session, then return the app-native session payload.

### App server contract

Server handoff is not the same endpoint as a browser OIDC callback. A normal callback such as `/auth/rosm/callback` receives `code` and `state` from a redirect. The SDK handoff endpoint receives a JSON POST from the app after the in-app UI has already finished ROSM Passport login and consent.

Recommended endpoints on the app server:

- `POST /auth/rosm/sdk/start`: create an app-side login challenge and return `state`, `nonce`, `client_id`, `redirect_uri`, `scope`, and the SDK handoff endpoint.
- `POST /auth/rosm/sdk/complete`: receive the SDK handoff JSON, verify it, exchange the authorization code, create the app session, and return the app session payload.

The `start` endpoint should bind the request to the current device/app session. Store `state`, `nonce`, requested scopes, redirect URI, expiry time, and a consumed flag. Return only values that the SDK should use.

```json
{
  "client_id": "com.cruos.zion",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "scope": "openid profile email phone accountRule",
  "state": "SERVER_GENERATED_STATE",
  "nonce": "SERVER_GENERATED_NONCE",
  "handoff_endpoint": "https://api.example.com/auth/rosm/sdk/complete"
}
```

The `complete` endpoint must:

- Require HTTPS and authenticate or bind the request to the same app/device challenge created by `start`.
- Check `issuer`, `client_id`, `redirect_uri`, `scope`, `state`, and `nonce` against the stored challenge.
- Reject missing, expired, already-consumed, or mismatched challenges.
- Exchange `code` at `${issuer}/oidc/token` with `client_secret`, `redirect_uri`, and `code_verifier`.
- Validate the ID token signature through the issuer JWKS, and validate `iss`, `aud`, `exp`, `iat`, and `nonce`.
- Treat the authorization code as one-time use. Mark the challenge consumed before or atomically with session creation.
- Create the app's own session or API token. Do not return ROSM `client_secret`; usually do not return ROSM refresh tokens to the app.
- Return a stable app-native response such as `{ "session_token": "...", "user": ... }`.

Example token exchange from the app server:

```http
POST https://auth.example.com/oidc/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "AUTHORIZATION_CODE",
  "client_id": "com.cruos.zion",
  "client_secret": "SERVER_ONLY_SECRET",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "code_verifier": "ORIGINAL_PKCE_VERIFIER"
}
```

If the app server already has a browser callback, keep it for browser redirects and add a separate SDK complete endpoint. Do not point `serverHandoffEndpoint` at a callback that only expects query parameters; it must accept the SDK JSON POST.

## Public direct mode

For simple apps that intentionally store ROSM tokens on device, configure the OIDC client as public and register a custom-scheme redirect URI such as `com.cruos.zion:/oidc/callback`.

```dart
final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('com.cruos.zion:/oidc/callback'),
);

final result = await showRosmPassportSignIn(context, client: passport);
final tokens = result?.tokens;
```

## Typed APIs

Apps can build custom UI and still avoid hand-written JSON:

```dart
final request = passport.createAuthorizationRequest(serverHandoff: true);
final start = await passport.startNativeAuthorization(request);

await passport.sendEmailLoginCode(email: 'user@example.com');
final auth = await passport.loginWithEmailCode(
  email: 'user@example.com',
  emailCode: '123456',
);

final approval = await passport.approveNativeAuthorization(request);
final handoff = await passport.completeServerHandoff(
  endpoint: Uri.parse('https://api.example.com/auth/rosm/sdk/complete'),
  request: request,
  approval: approval,
);
```

For password login, call `passwordFactors` before the final password login request. If `directLogin` is false, show the returned factors and then complete login with `factorType` plus the selected verification code. The built-in UI does this automatically.

## Registration

The built-in UI can create a ROSM account with email, nickname, password, and an email verification code. It opens the configured Aliyun Captcha challenge before requesting a registration code.

```dart
await passport.sendRegisterCode(
  email: 'user@example.com',
  captchaToken: captchaToken,
);

final auth = await passport.registerWithEmail(
  email: 'user@example.com',
  nickname: 'Rosemary',
  password: password,
  emailCode: '123456',
);
```

After registration succeeds, the built-in UI continues to the same consent and server handoff flow as a normal login.

## Account management

After the user signs in, apps can open the built-in account management page. It supports nickname updates, email and phone binding, password reset with email code, and Authenticator TOTP setup or updates.

```dart
await showRosmPassportAccountManagement(
  context,
  client: passport,
  config: RosmPassportAccountConfig(
    signInConfig: signInConfig,
  ),
);
```

The SDK uses the current ROSM first-party session cookie when available. In direct public mode it also sends the stored access token as a Bearer token for `/api/v1/me` operations. If the account session expires, pass the same `signInConfig` to `RosmPassportAccountConfig`; the account center can then open the built-in login flow instead of leaving the user on an expired-token screen.

## Password recovery

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

For phone recovery, pass the phone number as `account` and use `RosmPasswordRecoveryMethod.phone`.

## Required configuration

- Use server handoff for production apps with their own backend. The OIDC client can be confidential, but the `client_secret` stays on the app server.
- In server handoff mode, register the app server HTTPS redirect URI. Do not use a custom-scheme URI for the confidential client.
- If using direct public mode, register the custom-scheme redirect URI and keep the client public.
- Enable Authorization Code and Refresh Token grants, and require PKCE S256.
- Keep `openid` requests paired with a nonce. `RosmPassportClient.createAuthorizationRequest()` does this automatically.
