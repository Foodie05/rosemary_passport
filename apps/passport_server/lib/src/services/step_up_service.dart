import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'authenticator_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'webauthn_service.dart';

class StepUpService {
  StepUpService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required EmailCodeService emailCodeService,
    AuthenticatorService? authenticatorService,
    PhoneVerificationService? phoneVerificationService,
    WebAuthnService? webAuthnService,
    AuthThrottleService? throttleService,
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _emailCodes = emailCodeService,
       _authenticator = authenticatorService,
       _phones = phoneVerificationService,
       _webAuthn = webAuthnService,
       _throttles = throttleService;

  final UserRepository _users;
  final PasswordHasher _passwords;
  final EmailCodeService _emailCodes;
  final AuthenticatorService? _authenticator;
  final PhoneVerificationService? _phones;
  final WebAuthnService? _webAuthn;
  final AuthThrottleService? _throttles;

  static const _emailScope = 'verification-code:step-up:email';
  static const _ipScope = 'verification-code:step-up:ip';
  static const _cooldownScope = 'verification-code:step-up:cooldown:email';
  static const _verifyAccountScope = 'step-up:verify:account';
  static const _verifyIpScope = 'step-up:verify:ip';

  Future<List<String>> availableMethods(
    String userId, {
    String? excludedFactor,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) return const [];
    final methods = <String>[
      if (excludedFactor != 'password') 'password',
      if (excludedFactor != 'email' && user.isEmailVerified) 'email_code',
      if (excludedFactor != 'phone' &&
          user.isPhoneVerified &&
          (user.phoneNumber?.trim().isNotEmpty ?? false))
        'phone_code',
      if (excludedFactor != 'authenticator' && user.hasAuthenticator)
        'authenticator',
      if (excludedFactor != 'passkey' &&
          await (_webAuthn?.hasCredentials(user.id) ?? Future.value(false)))
        'passkey',
    ];
    return methods;
  }

  Future<CredentialActionAttempt> sendCode({
    required String userId,
    required String method,
    required String excludedFactor,
    String? requestIp,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) return _notFound;
    if (!await _isAllowed(user.id, method, excludedFactor)) {
      return _unavailable;
    }
    if (method == 'email_code') {
      final throttles = _throttles;
      if (throttles != null) {
        final policy = await throttles.loadPolicy();
        final limited = await throttles.enforceVerificationCodeSendGuards(
          email: user.email,
          requestIp: requestIp,
          policy: policy,
          emailScope: _emailScope,
          ipScope: _ipScope,
          cooldownScope: _cooldownScope,
          emailLimit: policy.adminLoginCodeEmailLimit,
          ipLimit: policy.adminLoginCodeIpLimit,
        );
        if (limited != null) {
          return CredentialActionAttempt.failure(
            code: limited.code,
            message: limited.message,
            statusCode: limited.statusCode,
          );
        }
        await _emailCodes.issueStepUpCode(user.email);
        await throttles.startVerificationCodeCooldown(
          email: user.email,
          seconds: policy.passwordResetCodeCooldownSeconds,
          cooldownScope: _cooldownScope,
        );
        return const CredentialActionAttempt.success();
      }
      await _emailCodes.issueStepUpCode(user.email);
      return const CredentialActionAttempt.success();
    }
    if (method == 'phone_code') {
      final phones = _phones;
      final phone = user.phoneNumber?.trim() ?? '';
      if (phones == null || phone.isEmpty) return _unavailable;
      final sent = await phones.sendCode(
        phoneNumber: phone,
        requestIp: requestIp?.trim() ?? '',
      );
      return sent.ok
          ? const CredentialActionAttempt.success()
          : CredentialActionAttempt.failure(
              code: sent.code ?? 'temporary_issue',
              message: sent.message ?? '验证码发送失败。',
              statusCode: sent.statusCode,
            );
    }
    return const CredentialActionAttempt.failure(
      code: 'invalid_factor',
      message: '该验证方式不需要发送验证码。',
    );
  }

  Future<Map<String, dynamic>?> beginPasskey({
    required String userId,
    required String excludedFactor,
    required String origin,
  }) async {
    if (!await _isAllowed(userId, 'passkey', excludedFactor)) return null;
    final user = await _users.findById(userId);
    return user == null
        ? null
        : _webAuthn?.generateAuthenticationOptions(
            email: user.email,
            userId: user.id,
            origin: origin,
            requireUserVerification: true,
          );
  }

  Future<CredentialActionAttempt> verify({
    required String userId,
    required String excludedFactor,
    required Map<String, dynamic> proof,
    String? requestIp,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) return _notFound;
    final method = (proof['method'] ?? '').toString().trim();
    if (!await _isAllowed(user.id, method, excludedFactor)) {
      return _unavailable;
    }
    final throttles = _throttles;
    if (throttles != null) {
      final policy = await throttles.loadPolicy();
      final limited = await throttles.enforceRequestGuards(
        emailScope: _verifyAccountScope,
        ipScope: _verifyIpScope,
        email: user.email,
        requestIp: requestIp,
        emailLimit: policy.loginEmailLimit,
        ipLimit: policy.loginIpLimit,
        window: Duration(seconds: policy.loginWindowSeconds),
        blockDuration: Duration(seconds: policy.loginBlockSeconds),
      );
      if (limited != null) {
        return CredentialActionAttempt.failure(
          code: limited.code,
          message: limited.message,
          statusCode: limited.statusCode,
        );
      }
    }
    var verified = false;
    if (method == 'password') {
      verified = await _passwords.verify(
        user.passwordHash,
        (proof['password'] ?? '').toString(),
      );
    } else if (method == 'email_code') {
      verified = await _emailCodes.verifyStepUpCode(
        user.email,
        (proof['code'] ?? '').toString().trim(),
      );
    } else if (method == 'phone_code') {
      final phone = user.phoneNumber?.trim() ?? '';
      final checked = await _phones?.verifyCode(
        phoneNumber: phone,
        verifyCode: (proof['code'] ?? '').toString().trim(),
        requestIp: requestIp?.trim() ?? '',
      );
      verified = checked?.ok == true;
    } else if (method == 'authenticator') {
      final secret = await _users.findAuthenticatorSecretByUserId(user.id);
      verified =
          secret != null &&
          (_authenticator?.verifyCode(
                secret: secret,
                code: (proof['code'] ?? '').toString().trim(),
              ) ??
              false);
    } else if (method == 'passkey' && proof['response'] is Map) {
      verified =
          await (_webAuthn?.verifyAuthentication(
                userId: user.id,
                email: user.email,
                response: Map<String, dynamic>.from(proof['response'] as Map),
                forceUserVerification: true,
              ) ??
              Future.value(false));
    }
    return verified
        ? const CredentialActionAttempt.success()
        : const CredentialActionAttempt.failure(
            code: 'verification_failed',
            message: '二次验证未通过，请重试。',
            statusCode: 401,
          );
  }

  Future<bool> _isAllowed(
    String userId,
    String method,
    String excludedFactor,
  ) async {
    return (await availableMethods(
      userId,
      excludedFactor: excludedFactor,
    )).contains(method);
  }

  static const _notFound = CredentialActionAttempt.failure(
    code: 'not_found',
    message: 'User not found.',
    statusCode: 404,
  );
  static const _unavailable = CredentialActionAttempt.failure(
    code: 'invalid_factor',
    message: '该验证方式不可用，或与当前变更项相同。',
    statusCode: 400,
  );
}
