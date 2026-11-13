// Generate the complete paired Epass palette with the pinned official HCT recipe.
import { generateColorRecipe, importColorScheme, validateTheme } from '@rosemary-ui/tokens';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
const root = new URL('../../', import.meta.url);
const config = { seed: '#315747', mood: 'calm' };
const recipe = generateColorRecipe(config);
const scheme = importColorScheme(recipe);
for (const mode of ['light', 'dark']) {
  const diagnostics = validateTheme(scheme[mode]);
  if (diagnostics.length) throw new Error(JSON.stringify({ mode, diagnostics }));
}
const product = { schemaVersion: 2, specVersion: '1.3.0', sdkVersion: '0.5.0', sourceCommit: '340d2f4531ea0f1e16d62537b02124e5823d8fa2', recipe: config, themes: recipe.themes };
writeFileSync(new URL('web/src/design/epass-theme.json', root), JSON.stringify(product, null, 2) + '\n');
const path = new URL('web/src/design/manifest.json', root);
const manifest = JSON.parse(readFileSync(path));
const sha = file => createHash('sha256').update(readFileSync(new URL(file, root))).digest('hex');
Object.assign(manifest.designSystem, { specVersion: product.specVersion, sdkVersion: product.sdkVersion, commit: product.sourceCommit, sourceSha256: sha('web/src/design/forma-source.json'), release: 'https://github.com/Foodie05/Rosemary-Design-System/releases/tag/v0.5.0', assets: ['icons','react','tokens'].map(name => { const path = `web/vendor/rosemary/rosemary-ui-${name}-0.5.0.tgz`; return { path, sha256: sha(path) }; }), flutterSourceArchiveSha256: 'b179c3f464f60a26a5a9d0c819b09ac68bf0f7c5ee570bd0a74e12c8eb9ffd38', provenance: 'web/vendor/rosemary/release-manifest-0.5.0.json' });
manifest.brand.approvedOverrides[0] = 'Retain the green Epass seed through the canonical HCT recipe, with 45 complete paired light/dark roles.';
manifest.tokens.recipe = 'node web/scripts/generate-theme.mjs';
manifest.passwordPolicy.reference = 'https://github.com/Foodie05/Rosemary-Design-System/blob/340d2f4531ea0f1e16d62537b02124e5823d8fa2/docs/sdk/input-validation.md';
manifest.passwordPolicy.referenceNote = 'Forma 1.3 shared creation policy, plus the existing Epass common-password rejection policy. Login remains compatible.';
manifest.passwordPolicy.rules = '8–32 U+0021–U+007E ASCII characters; at least two of letters, digits and punctuation; no spaces; retain identity-service common-password protection';
manifest.passwordPolicy.feedback = 'Official adjacent requirements: neutral initially, checked after the first nonempty blur, live after arming, composition-aware, reset on clearing.';
Object.assign(manifest.flutterSdk, { version:'0.5.0',productVersion:'0.11.0',commit:product.sourceCommit,path:'packages/rosm_passport_flutter/vendor/rosemary_ui',inputAdapter:'Official controlled input, controller/IME/autofill capabilities through the official editor contract.' });
manifest.validation.report = 'docs/forma-1.3-sdk-0.5.0-validation.md';
writeFileSync(path, JSON.stringify(manifest,null,2)+'\n');
console.log(`Generated 45 roles per mode; official contrast checks passed for both modes (${fileURLToPath(root)})`);
