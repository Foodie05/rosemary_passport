import assert from 'node:assert/strict';
import test from 'node:test';
import {copyText} from './clipboard.js';

function fallback(success) {
  const events = [];
  const field = {style:{},setAttribute:(...args)=>events.push(args),select:()=>events.push('select'),remove:()=>events.push('remove')};
  const document = {activeElement:{focus:()=>events.push('focus')},createElement:()=>field,body:{append:()=>events.push('append')},execCommand:command=>{events.push(command);return success;}};
  return {events,field,document};
}

test('clipboard copies the exact code with the native async API', async () => {
  const text = 'GET /.well-known/openid-configuration\n';
  let actual;
  await copyText(text,{secure:true,clipboard:{writeText:async value=>{actual=value;}}});
  assert.equal(actual,text);
});

test('clipboard fallback preserves text, removes its temporary field and restores focus', async () => {
  const mock = fallback(true);
  await copyText('code\nwith\nlines',{secure:true,clipboard:{writeText:async()=>{throw new Error('unavailable');}},document:mock.document});
  assert.equal(mock.field.value,'code\nwith\nlines');
  assert.deepEqual(mock.events.slice(-4),['select','copy','remove','focus']);
});

test('failed clipboard fallback reports failure and still cleans up', async () => {
  const mock = fallback(false);
  await assert.rejects(copyText('example',{secure:false,document:mock.document}),/复制失败/);
  assert.deepEqual(mock.events.slice(-2),['remove','focus']);
});
