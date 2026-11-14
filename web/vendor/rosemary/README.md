# Official Rosemary packages

Unmodified v0.5.0 release assets from [Rosemary Design System](https://github.com/Foodie05/Rosemary-Design-System/releases/tag/v0.5.0), source commit `340d2f4531ea0f1e16d62537b02124e5823d8fa2`, Forma 1.3.0. React 18.3.1 is retained.

SHA-256 values are recorded in `web/src/design/manifest.json` and verified by `npm test` against the vendored bytes. `package-lock.json` additionally locks npm integrity hashes. Installation uses relative file dependencies so clean consumers and CI need no unpublished registry package.

Upstream code is MIT; brand assets have separate terms in `BRAND-ASSETS.md`. The mother logo is unchanged. Product-owner overrides (green primary, capital initials and rounded tonal Epass badge) are recorded in the manifest; the product mark is not represented as an unmodified official asset.

The upstream `SHA256SUMS-0.5.0` and `release-manifest-0.5.0.json` are preserved alongside the archives. Flutter uses the matching unmodified source in `packages/rosm_passport_flutter/vendor/rosemary_ui`. Generated product colors use `node web/scripts/generate-theme.mjs`; `python3 scripts/sync_epass_tokens.py` regenerates both palettes and downstream surfaces.
