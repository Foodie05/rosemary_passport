import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import test from 'node:test';
import { validateTheme, contrastPairs } from '@rosemary-ui/tokens';
const read = path => readFileSync(new URL(path, import.meta.url));
const parse = path => JSON.parse(read(path));
const product = parse('./epass-theme.json');
const source = parse('./forma-source.json');
const manifest = parse('./manifest.json');
const camel = name => name.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
for (const mode of ['light', 'dark']) test(`${mode} has every Forma role and passes all ${contrastPairs.length} official contrast pairs`, () => {
  assert.deepEqual(Object.keys(product.themes[mode]).sort(), Object.keys(source.themes[mode]).sort());
  assert.deepEqual(validateTheme(Object.fromEntries(Object.entries(product.themes[mode]).map(([k,v]) => [camel(k),v]))), []);
  for (const role of ['danger','danger-soft','success','success-soft','warning','warning-soft','info','info-soft']) assert.equal(product.themes[mode][role],source.themes[mode][role]);
});
test('official release assets and source token snapshot match pinned SHA256', () => {
  for (const asset of manifest.designSystem.assets) assert.equal(createHash('sha256').update(read(`../../../${asset.path}`)).digest('hex'), asset.sha256, asset.path);
  assert.equal(createHash('sha256').update(read('./forma-source.json')).digest('hex'), manifest.designSystem.tokensSha256);
  assert.equal(source.sdkVersion,manifest.designSystem.sdkVersion);
  assert.equal(source.specVersion,manifest.designSystem.specVersion);
});
test('web and standalone pages share the same generated semantic CSS', () => {
  const css = read('./rosemary-tokens.css').toString();
  assert.ok(read('../../../apps/passport_server/lib/src/utils/epass_tokens.dart').toString().includes(css));
  assert.ok(read('../../public/maintenance.html').toString().includes(css));
  for (const palette of Object.values(product.themes)) for (const [name,value] of Object.entries(palette)) assert.ok(css.includes(`--r-semantic-color-${name}: ${value};`));
});
test('official mother brand asset is unchanged in web and SDK', () => {
  for (const path of ['../../public/brand/rosemary.png','../../../packages/rosm_passport_flutter/assets/rosemary.png']) assert.equal(createHash('sha256').update(read(path)).digest('hex'),manifest.brand.motherLogoSha256);
});
