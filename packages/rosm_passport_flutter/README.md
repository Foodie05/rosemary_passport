# rosm_passport_flutter

Flutter SDK for ROSM Passport native sign-in.

This package is intentionally UI-free. Apps provide their own screens for code input, passkey prompts, and consent confirmation while the SDK handles OIDC, PKCE, token exchange, token storage, and API calls.

```dart
final passport = RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'my_flutter_app',
  redirectUri: Uri.parse('com.example.app:/oidc/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone'},
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

Native mobile clients must be configured as public OIDC clients and use PKCE S256.
