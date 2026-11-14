export const roleMfaMethods = ['email_code','phone_code','authenticator','passkey'];
export function roleProofReady(proof) {
  return roleMfaMethods.includes(proof?.method) && (proof.method==='passkey' ? Boolean(proof.response?.id && proof.response?.response?.signature) : /^\d{6}$/.test(proof.code||''));
}
export function roleAssignmentPayload(roles,verification,supportedRoles) {
  if(!Array.isArray(roles)||!roles.length||!roles.every(role=>supportedRoles.includes(role)))throw new Error('请至少选择一个受支持的角色。');
  if(!roleProofReady(verification))throw new Error('应用更改前，请完成一种 MFA 验证。');
  const proof=verification.method==='passkey'?{method:'passkey',response:verification.response}:{method:verification.method,code:verification.code};
  return {roles:[...new Set(roles)],verification:proof};
}
