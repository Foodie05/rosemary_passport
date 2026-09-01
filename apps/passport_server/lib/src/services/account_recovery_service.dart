import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/password_policy.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'authenticator_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'session_service.dart';
import 'webauthn_service.dart';

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
    AuthenticatorService? authenticatorService,
    WebAuthnService? webAuthnService,
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _passwordPolicy = passwordPolicy,
       _emailCodes = emailCodeService,
       _throttles = throttleService,
       _sessions = sessionService,
       _phones = phoneVerificationService,
       _authenticator = authenticatorService,
       _webAuthn = webAuthnService;

  static const _resetEmailScope = 'verification-code:password-reset:email';
  static const _resetIpScope = 'verification-code:password-reset:ip';
  static const _resetCooldownScope =
      'verification-code:password-reset:cooldown:email';
  static const _resetPhoneScope = 'verification-code:password-reset:phone';
  static const _resetPhoneIpScope = 'verification-code:password-reset:phone:ip';
  static const _resetPhoneCooldownScope =
      'verification-code:password-reset:cooldown:phone';
  static const _verifyAccountScope = 'password-recovery:verify:account';
  static const _verifyIpScope = 'password-recovery:verify:ip';

  final UserRepository _users;
  final PasswordHasher _passwords;
  final PasswordPolicy _passwordPolicy;
  final EmailCodeService _emailCodes;
  final AuthThrottleService _throttles;
  final SessionService _sessions;
  final PhoneVerificationService? _phones;
  final AuthenticatorService? _authenticator;
  final WebAuthnService? _webAuthn;

  Future<EmailActionAttempt> sendCode({
    required String account,
    required String method,
    String? requestIp,
  }) async {
    final normalizedMethod = method.trim();
    if (normalizedMethod == 'email') {
      final normalizedAccount = account.trim().toLowerCase();
      final policy = await _throttles.loadPolicy();
      final limited = await _throttles.enforceVerificationCodeSendGuards(
        email: normalizedAccount,
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
      final user = await _users.findByEmail(normalizedAccount);
      if (user != null) {
        try {
          await _emailCodes.issuePasswordResetCode(user.email);
        } catch (_) {
          // The public response intentionally hides delivery and account state.
        }
      }
      await _throttles.startVerificationCodeCooldown(
        email: normalizedAccount,
        seconds: policy.passwordResetCodeCooldownSeconds,
        cooldownScope: _resetCooldownScope,
      );
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
      final policy = await _throttles.loadPolicy();
      final limited = await _throttles.enforceVerificationCodeSendGuards(
        email: normalized,
        requestIp: requestIp,
        policy: policy,
        emailScope: _resetPhoneScope,
        ipScope: _resetPhoneIpScope,
        cooldownScope: _resetPhoneCooldownScope,
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
      final user = await _users.findByPhoneNumber(normalized);
      if (user != null) {
        try {
          await phones.sendCode(
            phoneNumber: normalized,
            requestIp: requestIp?.trim() ?? '',
          );
        } catch (_) {
          // The public response intentionally hides delivery and account state.
        }
      }
      await _throttles.startVerificationCodeCooldown(
        email: normalized,
        seconds: policy.passwordResetCodeCooldownSeconds,
        cooldownScope: _resetPhoneCooldownScope,
      );
      return const EmailActionAttempt.success();
    }
    if (normalizedMethod == 'authenticator' || normalizedMethod == 'passkey') {
      // No delivery is needed. Keep the public response non-enumerating.
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
    Map<String, dynamic>? passkeyResponse,
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
    if (normalizedMethod == 'authenticator' || normalizedMethod == 'passkey') {
      final policy = await _throttles.loadPolicy();
      final passkeyCredentialId = passkeyResponse == null
          ? ''
          : ((passkeyResponse['id'] ?? passkeyResponse['rawId']) ?? '')
                .toString();
      final subject = normalizedMethod == 'passkey'
          ? 'passkey:$passkeyCredentialId'
          : 'authenticator:${account.trim().toLowerCase()}';
      final limited = await _throttles.enforceRequestGuards(
        emailScope: _verifyAccountScope,
        ipScope: _verifyIpScope,
        email: subject,
        requestIp: requestIp,
        emailLimit: policy.loginEmailLimit,
        ipLimit: policy.loginIpLimit,
        window: Duration(seconds: policy.loginWindowSeconds),
        blockDuration: Duration(seconds: policy.loginBlockSeconds),
      );
      if (limited != null) {
        return EmailActionAttempt.failure(
          code: limited.code,
          message: limited.message,
          statusCode: limited.statusCode,
        );
      }
    }
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
    } else if (normalizedMethod == 'authenticator') {
      user = await _findAccount(account);
      final secret = user == null
          ? null
          : await _users.findAuthenticatorSecretByUserId(user.id);
      if (secret == null ||
          !(_authenticator?.verifyCode(secret: secret, code: code.trim()) ??
              false)) {
        return const EmailActionAttempt.failure(
          code: 'invalid_code',
          message: '验证信息无效或已过期。',
          statusCode: 401,
        );
      }
    } else if (normalizedMethod == 'passkey') {
      final response = passkeyResponse;
      final credentialId = response == null
          ? ''
          : ((response['id'] ?? response['rawId']) ?? '').toString();
      final credential = credentialId.isEmpty
          ? null
          : await _webAuthn?.findCredential(credentialId);
      user = credential == null
          ? null
          : await _users.findById(credential.userId);
      final accountUser = account.trim().isEmpty
          ? user
          : await _findAccount(account);
      final verified =
          user != null &&
          accountUser?.id == user.id &&
          response != null &&
          await (_webAuthn?.verifyAuthentication(
                userId: user.id,
                email: user.email,
                response: response,
                forceUserVerification: true,
              ) ??
              Future.value(false));
      if (!verified) {
        return const EmailActionAttempt.failure(
          code: 'verification_failed',
          message: '通行密钥验证失败。',
          statusCode: 401,
        );
      }
    } else {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'unsupported recovery method',
        statusCode: 400,
      );
    }

    final resolvedUser = user;
    if (resolvedUser == null) {
      return const EmailActionAttempt.failure(
        code: 'verification_failed',
        message: '验证信息无效或已过期。',
        statusCode: 401,
      );
    }
    final passwordHash = await _passwords.hash(newPassword.trim());
    await _users.updatePasswordHash(
      userId: resolvedUser.id,
      passwordHash: passwordHash,
    );
    await _sessions.revokeAllUserSessions(resolvedUser.id);
    return const EmailActionAttempt.success();
  }

  Future<UserRecord?> _findAccount(String account) async {
    final normalized = account.trim();
    if (normalized.contains('@')) {
      return _users.findByEmail(normalized.toLowerCase());
    }
    final phone = _phones?.normalizePhone(normalized);
    return phone == null ? null : _users.findByPhoneNumber(phone);
  }
}
