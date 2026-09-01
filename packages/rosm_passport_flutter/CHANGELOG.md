## 0.7.1

- Support password plus email-code two-factor login for administrator accounts while keeping existing email-code login compatible for standard accounts.

## 0.7.0

- Add system-adaptive light and dark themes to the built-in sign-in and account-management screens.
- Add explicit `RosmPassportThemeMode.light` and `RosmPassportThemeMode.dark` overrides.
- Keep phone-number and other input text readable independently of the host application's theme.
- Share one refresh-token rotation across concurrent unauthorized requests to avoid replay-family revocation.

## 0.6.1

- Run Aliyun Captcha before sending login, registration, recovery, and MFA codes.

## 0.6.0

- Add secure refresh-token storage and automatic access-token renewal.
- Add remembered non-secret sign-in hints and account reauthentication.
- Remove the experimental native Passkey surface pending a stable cross-platform contract.
