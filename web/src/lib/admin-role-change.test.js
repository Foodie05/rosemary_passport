import test from 'node:test';
import assert from 'node:assert/strict';
import {roleAssignmentPayload,roleProofReady} from './admin-role-change.js';
const supported=['user','admin'];
test('role assignment accepts supported selections and only one complete MFA proof',()=>{
  for(const method of ['email_code','phone_code','authenticator']) {
    assert.deepEqual(roleAssignmentPayload(['user','admin','user'],{method,code:'123456',password:'never-forward',actor_id:'spoofed'},supported),{roles:['user','admin'],verification:{method,code:'123456'}});
  }
  const response={id:'credential',response:{signature:'signed'}};
  assert.deepEqual(roleAssignmentPayload(['admin'],{method:'passkey',response},supported),{roles:['admin'],verification:{method:'passkey',response}});
});
test('empty roles, unsupported roles and passwords cannot bypass role MFA',()=>{
  for(const roles of [[],['superadmin'],['user','superadmin']])assert.throws(()=>roleAssignmentPayload(roles,{method:'email_code',code:'123456'},supported));
  for(const proof of [{},{method:'password',password:'valid-password'},{method:'email_code',code:''},{method:'authenticator',code:'12345'},{method:'passkey',response:{}},{method:'unknown',code:'123456'}]) {
    assert.equal(roleProofReady(proof),false);
    assert.throws(()=>roleAssignmentPayload(['admin'],proof,supported));
  }
});
