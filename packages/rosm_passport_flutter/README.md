# rosm_passport_flutter

Flutter SDK for ROSM Passport native sign-in.

This package is intentionally UI-free. Apps provide their own screens for code input, captcha, passkey prompts, password recovery, and consent confirmation while the SDK handles OIDC, PKCE, token exchange, token storage, cookies, and API calls.

```dart
final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('com.cruos.zion:/oidc/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone', 'accountRule'},
  webAuthnOrigin: Uri.parse('https://auth.example.com'),
);

final request = passport.createAuthorizationRequest();
final start = await passport.startNativeAuthorization(request);
print('Authorize ${start.client.displayName}');

await passport.sendEmailLoginCode(email: 'user@example.com');
final session = await passport.loginWithEmailCode(
  email: 'user@example.com',
  emailCode: '123456',
);

final approval = await passport.approveNativeAuthorization(request);
final tokens = await passport.exchangeCode(
  request: request,
  approval: approval,
);
final user = await passport.userInfo();
print('Signed in as ${session.user.nickname}; subject=${user.sub}');
```

Native mobile clients must be configured as public OIDC clients and use PKCE S256. A single package-style `client_id` can enable both Web and App redirects; if App is enabled, keep that client public. Use a separate Web-only confidential client only when the web callback must require `client_secret`.

## Password recovery

Use the recovery methods instead of building JSON requests in the app:

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

## Passkeys

The SDK wraps the ROSM Passport WebAuthn endpoints, but the app still calls the platform passkey API or a Flutter passkey plugin to show the system sheet. The app should pass the returned credential response back to the SDK as `RosmWebAuthnCredential`.

### Sign in with a passkey

```dart
final options = await passport.beginWebAuthnLogin(
  email: 'user@example.com',
);

final credentialResponse = await yourPasskeyPlugin.authenticate(
  options.options,
);

final session = await passport.completeWebAuthnLogin(
  email: 'user@example.com',
  credential: RosmWebAuthnCredential(credentialResponse),
);
```

The `email` parameter is optional when the app wants discoverable passkeys.

### Add a passkey to the current account

After a normal login, ask for the current password before adding a passkey:

```dart
final options = await passport.beginPasskeyRegistration(
  currentPassword: currentPassword,
);

final credentialResponse = await yourPasskeyPlugin.register(options.options);

await passport.completePasskeyRegistration(
  credential: RosmWebAuthnCredential(credentialResponse),
);
```

Immediately after self-registration, if the server response has `postRegisterPasskeyBootstrap == true`, the app may use the short-lived bootstrap path:

```dart
final options = await passport.beginPasskeyRegistration(
  postRegisterBootstrap: true,
);
```

### Manage passkeys

```dart
final passkeys = await passport.listPasskeys();

await passport.deletePasskey(passkeys.credentials.first.credentialId);
```

## Required configuration

- Create or edit the package-style OIDC client, for example `com.cruos.zion`, enable App, and keep it public. Do not ship `client_secret` in Flutter.
- Web and App can be enabled on the same package client. If Web must require `client_secret`, use a separate Web-only confidential client.
- Enable Authorization Code and Refresh Token grants, and require PKCE S256.
- Register the app redirect URI exactly, for example `com.cruos.zion:/oidc/callback`.
- Configure Associated Domains on iOS and Digital Asset Links on Android for the WebAuthn relying party domain.
- Set `webAuthnOrigin` to the HTTPS origin that matches the server WebAuthn RP ID, usually the issuer origin such as `https://auth.example.com`.
- Keep `openid` requests paired with a nonce. `RosmPassportClient.createAuthorizationRequest()` does this automatically.
