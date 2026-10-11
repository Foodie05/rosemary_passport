// Mirrors the server's new-password policy. Login passwords remain unrestricted.
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 128;
const blocked = new Set(["1234567","12345678","123456789","1234567890","abcd1234","abc12345","qazwsx12","asdf1234","123456789012", "123456789123", "123456789abc", "1234567890ab", "012345678901", "987654321098", "abcdefghijkl", "abcdefgh1234", "abcd1234abcd", "password1234", "password123!", "password12345", "password@123", "passw0rd1234", "p@ssword1234", "p@ssw0rd1234", "qwertyuiop12", "qwerty123456", "qwertyuiop123", "qwerty123456789", "asdfghjkl123", "zxcvbnm12345", "admin1234567", "administrator", "letmein123456", "welcome12345", "iloveyou1234", "changeme1234", "monkey123456", "dragon123456", "football1234", "baseball12345", "sunshine1234", "princess1234", "trustno112345", "superman1234", "computer1234", "internet1234", "master123456", "login1234567", "secret123456", "welcome@123", "qazwsx123456", "1q2w3e4r5t6y", "1qaz2wsx3edc", "111111111111"]);
const commonBase = /^(?:password|passw0rd|p(?:a|4)ssw(?:o|0)rd|qwerty|admin|administrator|letmein|welcome|iloveyou|changeme|monkey|dragon|football|baseball|sunshine|princess|trustno1|superman|computer|internet|master|login|secret)\d*$/;
export function evaluatePassword(password = '') {
  const length = [...password].length;
  const lower = password.toLowerCase();
  const normalized = lower.replaceAll('@', 'a').replaceAll('$', 's').replace(/[^a-z0-9]/g, '');
  const lengthValid = length >= PASSWORD_MIN_LENGTH && length <= PASSWORD_MAX_LENGTH;
  const formatValid = /^[\x20-\x7e]*$/.test(password) && password === password.trim();
  const compositionValid = [/[a-zA-Z]/.test(password), /[0-9]/.test(password), /[!-/:-@\[-`{-~]/.test(password)].filter(Boolean).length >= 2;
  const uncommon = !blocked.has(lower) && !blocked.has(normalized) && !commonBase.test(normalized) && !/^(.{1,4})\1{2,}$/.test(lower);
  const message = !lengthValid ? (length < PASSWORD_MIN_LENGTH ? `不少于 8 个字符，还需 ${PASSWORD_MIN_LENGTH - length} 个。` : '最多 128 个字符，请缩短密码。')
    : !formatValid ? '请使用英文字母、数字或符号，首尾不能有空格。'
    : !compositionValid ? '字母、数字、符号中至少包含两种。'
    : !uncommon ? '这个密码很容易被猜到，请避开常见词、连续字符或重复模式。' : '';
  return { ok: lengthValid && formatValid && compositionValid && uncommon, length, lengthValid, formatValid, compositionValid, uncommon, message };
}
export function passwordContainsPersonalInfo(password = '', personalInfo = []) {
  const lower = password.toLowerCase();
  return personalInfo.some(value => {
    const candidate = `${value || ''}`.trim().toLowerCase().split('@')[0];
    return candidate.length >= 3 && lower.includes(candidate);
  });
}
