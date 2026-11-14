# Rosemary Flutter SDK 0.5.0

> 0.5.0 implements Forma 1.3.0 with 45 semantic roles, paired scheme imports, and portal-aligned controls and disclosure curves. See `docs/sdk/0.5.0-migration.md` and `docs/sdk/0.5.0-parity.md`. The Release manifest records exact-main CI provenance; historical evidence below is not a substitute.


`rosemary_ui` implements the 33 foundation components from `design/contracts.json`. The library contains UI, typed theme roles and callbacks; application data, navigation, uploads and persistence stay in the host. Code is MIT; the name and brand identity remain separately governed.

Use Flutter **3.44.8 / Dart 3.12.2**. The example configures Android API **26**, iOS **17**, and macOS **12**. Windows and Linux builds run on Windows 2022 and Ubuntu 24.04 CI; their older OS compatibility has not been established. Browser support is the latest two major versions of Chrome, Edge, Firefox and Safari; building Web alone does not certify that matrix.

## Install

Extract `rosemary-ui-0.5.0-source.tar.gz` into your project’s vendor directory:

```yaml
dependencies:
  rosemary_ui:
    path: vendor/rosemary_ui
```

The same package can be consumed from the repository through a pinned Git commit and `path: platforms/flutter/rosemary_ui`; no public pub release is required. Import `package:rosemary_ui/rosemary_ui.dart`. Source archives contain LICENSE and generated token/icon data.

```dart
RosemaryTheme(
  mode: RosemaryThemeMode.system,
  locale: const Locale('zh'),
  direction: TextDirection.rtl,
  child: RosemaryButton(label: '保存', onPressed: save),
)
```

`RosemaryThemeData.of(context)` returns the typed `ThemeExtension` and all 24 semantic colors. `colors:` sets a complete local palette; use `RosemaryTokens.light/dark.copyWith(...)`. The example loads `assets/vigilo.json`, a byte-checked generated mirror of the full shared `design/themes/vigilo.json` palette. Local dialogs, popovers and select panels inherit the opening theme, locale, direction, text scale and reduced motion. `highContrastColors:` supplies an explicit complete palette when `MediaQuery.highContrast` is true; the example raises control/border/focus contrast through the existing ink role. Custom colors are never silently adjusted.

Theme diagnostics report the shared 22 contrast pairs with measured ratios and targets. Colors must be opaque finite sRGB; `onContrastDiagnostics` fires only for an effective palette change and can safely store results through host `setState`. OS brightness, text scale, disabled animations, high contrast and inherited/system locale are observed at runtime. `reduceMotion: true` explicitly requests static or immediate transitions.

## Verify a real package consumer

```sh
python3 platforms/flutter/scripts/verify.py test
python3 platforms/flutter/scripts/verify.py android
python3 platforms/flutter/scripts/verify.py web
python3 platforms/flutter/scripts/verify.py macos
python3 platforms/flutter/scripts/verify.py ios
```

The script creates a deterministic source archive, extracts it into an isolated vendor package, copies the example and builds against that extracted package. `test` runs library checks, extracted-package regression checks and the 33-component gallery in both themes. `device` runs representative native interactions from the same isolated consumer; set `ROSEMARY_FLUTTER_DEVICE` to a connected device or desktop target. Windows and Linux modes run on their native CI hosts. Set `ROSEMARY_BUILD_ROOT`, `ROSEMARY_ARTIFACT_ROOT`, `PUB_CACHE` and `GRADLE_USER_HOME` for external cache/build storage.

Artifacts use `rosemary-flutter-0.5.0-{android.apk,web.zip,macos.zip,ios-simulator.zip,windows.zip,linux.tar.gz}`. Apple ZIPs use `ditto` to preserve bundle permissions and symlinks. Desktop archives are extracted and launched for a separate smoke check; this does not substitute for keyboard or screen reader interaction checks. `verification.json`, `SHA256SUMS` and phase logs record actual tool versions, source inputs, Git/GitHub HEAD and outcomes.

CI verifies library and extracted-package tests, a real source-archive consumer, all six target builds, and representative native editing/date-cancel/progress-stop interactions on Linux, macOS, Windows and Android API36. The native case executes the actual application `main()` and reads the bundled full Vigilo theme. Every target archive must contain the canonical theme resource byte-for-byte; desktop launch logs must not report Flutter startup exceptions. A successful build alone is insufficient.

Authoritative release evidence is the bundle's `verification.json`, `SHA256SUMS` and manifest for its exact clean Git HEAD; development outputs with `dirtyWorkingTree: true` are not release proof. Hosted Apple validation uses macOS15 and Xcode26.3; local development used Xcode27 beta. Physical iOS signing/device execution, older Windows/Linux compatibility and manual TalkBack/VoiceOver/NVDA/browser screen-reader audits are not certified. Representative high-contrast/text-scale checks do not claim every component across every OS or font scale.

## Migration from v0.3.0-prototype.2

The old package was `rosemary_reference` with entry point `rosemary.dart`; replace these with `rosemary_ui` / `rosemary_ui.dart`. The former six-field `RosemaryTheme extends ThemeExtension` is now the `RosemaryTheme` provider widget plus `RosemaryThemeData` extension. Old `accent/onAccent` become `primary/onPrimary`, `ink` remains `ink`, and the old control-border field maps to `control`; `surface`, `danger` remain explicit roles. The new palette has 24 required roles, so start with the new light/dark preset rather than constructing the old six-field theme.

Old `RosemaryTextField` calls migrate to controlled `RosemaryInput(value:, onChanged:, label:)`; `RosemaryButton.loading` becomes `busy`. The old extra APIs such as `RosemaryButtonGroup`, `RosemarySplitButton`, `RosemaryFloatingActionButton`, `RosemaryColorPicker` and `RosemarySidebar` are outside the 33-component scope and are not compatibility exports. Custom local date/time types and dedicated year/month/time-column selectors replace the prototype date/time picker APIs; cancel discards drafts. Loader geometry, short-task delay and lifecycle behavior follow the shared 0.4.0 contracts. This is an API migration, not a drop-in compatible update.
