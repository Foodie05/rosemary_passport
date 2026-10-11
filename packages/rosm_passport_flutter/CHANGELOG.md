## 0.9.0 — 2026-10-11

- Rename built-in product branding to Rosemary Epass and bundle the official logo.
- Integrate official Rosemary Design Flutter SDK 0.3.0-prototype.2 at a fixed commit; align semantic light/dark colors, fields, controls, panels and motion. Primary actions adapt to iOS/Android and retain their labels while loading.
- Add `RosmPasswordPolicy`, `RosmPasswordValidation` and `RosmNewPasswordField` for immediate registration/recovery/account-password feedback. New passwords require 8–128 characters and two of letters/digits/symbols; the usual hint omits the upper limit.
- Validate new-password client calls before HTTP; preserve legacy password login and existing public API identifiers.
- Keep a single live form during selection transitions; honor reactive system reduced motion. Preserve MFA code focus and keyboard visibility after sending.
- **Runtime change:** require Flutter >=3.44 / Dart >=3.12 to use the official design SDK. Upstream remains Prototype; manual screen-reader/device acceptance is not claimed.

## 0.8.1

- Keep version-bound Terms of Use and Privacy Policy acceptance visible in the built-in sign-in and registration flow.
- Replace the generic legal document alert with a Rosemary-styled, theme-adaptive reading dialog.
- Present the legal acceptance row as lightweight text without a bulky container.
- Update custom-UI integration guidance so every login submits the currently published legal versions.

## 0.8.0

- Load the currently published ROSM Pass Terms of Use and Privacy Policy and require explicit acceptance before every completed sign-in or registration.
- Add version-bound legal acceptance parameters to password, email-code, phone-code, registration, and direct step-up client APIs.
- Present both agreements in readable dialogs while preserving system-adaptive light/dark styling and high-contrast phone input text.

## 0.7.2

- Send login codes before resolving account existence, then expose a signed registration handoff only after a valid email or phone code.
- Let the built-in sign-in flow complete registration without requesting a second verification code.
- Add direct-login step-up APIs and a factor-choice screen instead of an administrator-password field.
- Preserve the legacy optional password argument for existing 0.7.1 integrations.

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
