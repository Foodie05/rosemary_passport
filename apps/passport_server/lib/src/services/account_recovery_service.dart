import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/password_policy.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'session_service.dart';

/// Implements non-enumerating password recovery for email and phone accounts.
class AccountRecoveryService {
  AccountRecoveryService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required PasswordPolicy passwordPolicy,
    required EmailCodeService emailCodeService,
    required AuthThrottleService throttleService,
    required SessionService sessionService,
    PhoneVerificationService? phoneVerificationService,
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _passwordPolicy = passwordPolicy,
       _emailCodes = emailCodeService,
       _throttles = throttleService,
       _sessions = sessionService,
       _phones = phoneVerificationService;

  static const _resetEmailScope = 'verification-code:password-reset:email';
  static const _resetIpScope = 'verification-code:password-reset:ip';
  static const _resetCooldownScope =
      'verification-code:password-reset:cooldown:email';

  final UserRepository _users;
  final PasswordHasher _passwords;
  final PasswordPolicy _passwordPolicy;
  final EmailCodeService _emailCodes;
  final AuthThrottleService _throttles;
  final SessionService _sessions;
  final PhoneVerificationService? _phones;

  Future<EmailActionAttempt> sendCode({
    required String account,
    required String method,
    String? requestIp,
  }) async {
    final normalizedMethod = method.trim();
    if (normalizedMethod == 'email') {
      final user = await _users.findByEmail(account.trim().toLowerCase());
      if (user != null) {
        final policy = await _throttles.loadPolicy();
        final limited = await _throttles.enforceVerificationCodeSendGuards(
          email: user.email,
          requestIp: requestIp,
          policy: policy,
          emailScope: _resetEmailScope,
          ipScope: _resetIpScope,
          cooldownScope: _resetCooldownScope,
          emailLimit: policy.adminLoginCodeEmailLimit,
          ipLimit: policy.adminLoginCodeIpLimit,
        );
        if (limited != null) {
          return EmailActionAttempt.failure(
            code: limited.code,
            message: limited.message,
            statusCode: limited.statusCode,
          );
        }
        await _emailCodes.issuePasswordResetCode(user.email);
        await _throttles.startVerificationCodeCooldown(
          email: user.email,
          seconds: policy.passwordResetCodeCooldownSeconds,
          cooldownScope: _resetCooldownScope,
        );
      }
      // Do not disclose whether an account exists.
      return const EmailActionAttempt.success();
    }
    if (normalizedMethod == 'phone') {
      final phones = _phones;
      if (phones == null) {
        return const EmailActionAttempt.failure(
          code: 'phone_verification_not_configured',
          message: '手机号验证码服务尚未配置。',
          statusCode: 503,
        );
      }
      final normalized = phones.normalizePhone(account);
      if (normalized == null) {
        return const EmailActionAttempt.failure(
          code: 'invalid_phone_number',
          message: '手机号格式不正确。',
        );
      }
      final user = await _users.findByPhoneNumber(normalized);
      if (user != null) {
        final sent = await phones.sendCode(
          phoneNumber: normalized,
          requestIp: requestIp?.trim() ?? '',
        );
        if (!sent.ok) {
          return EmailActionAttempt.failure(
            code: sent.code ?? 'temporary_issue',
            message: sent.message ?? '验证码发送失败，请稍后重试。',
            statusCode: sent.statusCode,
          );
        }
      }
      return const EmailActionAttempt.success();
    }
    return const EmailActionAttempt.failure(
      code: 'invalid_request',
      message: 'unsupported recovery method',
      statusCode: 400,
    );
  }

  Future<EmailActionAttempt> recoverPassword({
    required String account,
    required String method,
    required String code,
    required String newPassword,
    String? requestIp,
  }) async {
    if (newPassword.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'new_password is required.',
      );
    }
    final policy = _passwordPolicy.validate(newPassword);
    if (!policy.ok) {
      return EmailActionAttempt.failure(
        code: 'password_policy_violation',
        message: policy.message!,
      );
    }

    final normalizedMethod = method.trim();
    UserRecord? user;
    if (normalizedMethod == 'email') {
      user = await _users.findByEmail(account.trim().toLowerCase());
      if (user == null ||
          !await _emailCodes.verifyPasswordResetCode(user.email, code.trim())) {
        return const EmailActionAttempt.failure(
          code: 'invalid_code',
          message: '验证码无效或已过期。',
          statusCode: 401,
        );
      }
    } else if (normalizedMethod == 'phone') {
      final phones = _phones;
      if (phones == null) {
        return const EmailActionAttempt.failure(
          code: 'phone_verification_not_configured',
          message: '手机号验证码服务尚未配置。',
          statusCode: 503,
        );
      }
      final normalized = phones.normalizePhone(account);
      if (normalized == null) {
        return const EmailActionAttempt.failure(
          code: 'invalid_phone_number',
          message: '手机号格式不正确。',
        );
      }
      user = await _users.findByPhoneNumber(normalized);
      if (user == null) {
        return const EmailActionAttempt.failure(
          code: 'invalid_code',
          message: '验证码无效或已过期。',
          statusCode: 401,
        );
      }
      final checked = await phones.verifyCode(
        phoneNumber: normalized,
        verifyCode: code.trim(),
        requestIp: requestIp?.trim() ?? '',
      );
      if (!checked.ok) {
        return EmailActionAttempt.failure(
          code: checked.code ?? 'invalid_code',
          message: checked.message ?? '验证码无效或已过期。',
          statusCode: checked.statusCode,
        );
      }
    } else {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'unsupported recovery method',
        statusCode: 400,
      );
    }

    final passwordHash = await _passwords.hash(newPassword.trim());
    await _users.updatePasswordHash(
      userId: user.id,
      passwordHash: passwordHash,
    );
    await _sessions.revokeAllUserSessions(user.id);
    return const EmailActionAttempt.success();
  }
}
