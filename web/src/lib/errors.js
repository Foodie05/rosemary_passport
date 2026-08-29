const ERROR_MESSAGES = {
  captcha_failed: '人机验证未通过，请重新验证后再试。',
  conflict: '提交的信息与现有数据冲突，请检查后重试。',
  forbidden: '你没有权限执行此操作。',
  invalid_authorization_request: '授权请求无效，请返回后重新发起。',
  invalid_email_code: '邮箱验证码无效或已过期。',
  invalid_factor: '当前验证方式不可用，请重新选择。',
  invalid_grant: '登录状态已失效，请重新登录。',
  invalid_password: '当前密码错误，请重新输入。',
  invalid_request: '提交的信息不完整或格式不正确，请检查后重试。',
  invalid_totp_code: '验证信息无效，请重新输入。',
  login_failed: '账号或密码错误。',
  method_not_allowed: '当前操作暂不支持，请返回后重试。',
  mfa_required: '请完成二次验证后继续。',
  network_error: '当前无法连接到服务，请检查网络后重试。',
  not_configured: '当前账户尚未配置此验证方式。',
  not_found: '未找到所需信息，请刷新页面后重试。',
  rate_limited: '操作过于频繁，请稍后再试。',
  server_error: '服务暂时不可用，请稍后重试。',
  temporary_issue: '服务暂时不可用，请稍后重试。',
  verification_failed: '验证未通过，请重新尝试。',
};

const TECHNICAL_MESSAGE = /(?:\bis not a function\b|\b(?:type|reference|syntax|network)error\b|\bundefined\b|\bnull\b|\bcannot\s+(?:read|access)\b|\bfailed to fetch\b|\bunexpected token\b|\bstack\b)/i;

function isSafeChineseMessage(value) {
  return /[\u3400-\u9fff]/.test(value) && !TECHNICAL_MESSAGE.test(value);
}

/** Returns an error text that is safe to show to end users. */
export function getUserErrorMessage(error, fallback = '操作未完成，请稍后重试。') {
  const code = String(error?.code || '').trim();
  if (ERROR_MESSAGES[code]) {
    return ERROR_MESSAGES[code];
  }

  const serverMessage = String(error?.serverMessage || error?.message || '').trim();
  return isSafeChineseMessage(serverMessage) ? serverMessage : fallback;
}

/** Sanitizes messages passed to global UI feedback components. */
export function getUserMessage(message, fallback = '操作未完成，请稍后重试。') {
  const value = String(message || '').trim();
  return isSafeChineseMessage(value) ? value : fallback;
}
