import 'package:uuid/uuid.dart';

import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/password_policy.dart';
import '../security/token_service.dart';
import 'audit_service.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'security_policy_service.dart';
import 'session_service.dart';

/// Owns email and phone self-registration without changing existing rows.
class RegistrationService {
  RegistrationService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required PasswordPolicy passwordPolicy,
    required TokenService tokenService,
    required EmailCodeService emailCodeService,
    required AuthThrottleService throttleService,
    required SessionService sessionService,
    required AuditService auditService,
    SecurityPolicyService? securityPolicyService,
    PhoneVerificationService? phoneVerificationService,
    Uuid uuid = const Uuid(),
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _passwordPolicy = passwordPolicy,
       _tokens = tokenService,
       _emailCodes = emailCodeService,
       _throttles = throttleService,
       _sessions = sessionService,
       _audit = auditService,
       _policy = securityPolicyService,
       _phones = phoneVerificationService,
       _uuid = uuid;

  static const _registerEmailScope = 'verification-code:register:email';
  static const _registerIpScope = 'verification-code:register:ip';
  static const _registerCooldownScope =
      'verification-code:register:cooldown:email';

  final UserRepository _users;
  final PasswordHasher _passwords;
  final PasswordPolicy _passwordPolicy;
  final TokenService _tokens;
  final EmailCodeService _emailCodes;
  final AuthThrottleService _throttles;
  final SessionService _sessions;
  final AuditService _audit;
  final SecurityPolicyService? _policy;
  final PhoneVerificationService? _phones;
  final Uuid _uuid;

  Future<AdminLoginCodeAttempt> sendEmailCode({
    required String email,
    String? requestIp,
  }) async {
    final providerPolicy = await _emailProviderPolicy();
    if (!providerPolicy.allows(email)) {
      return const AdminLoginCodeAttempt.failure(
        code: 'registration_email_not_allowed',
        message: '此邮箱不可用于注册',
        statusCode: 403,
      );
    }
    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceVerificationCodeSendGuards(
      email: email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _registerEmailScope,
      ipScope: _registerIpScope,
      cooldownScope: _registerCooldownScope,
      emailLimit: policy.registerCodeEmailLimit,
      ipLimit: policy.registerCodeIpLimit,
    );
    if (limited != null) {
      return limited;
    }
    await _emailCodes.issueRegisterCode(email);
    await _throttles.startVerificationCodeCooldown(
      email: email,
      seconds: policy.registerCodeCooldownSeconds,
      cooldownScope: _registerCooldownScope,
    );
    return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
  }

  Future<RegisterAttempt> registerWithEmail({
    required String email,
    required String nickname,
    required String password,
    String? emailCode,
    String? registrationHandoff,
    String? requestIp,
  }) async {
    final passwordFailure = _validatePassword(password);
    if (passwordFailure != null) {
      return passwordFailure;
    }
    if (!(await _emailProviderPolicy()).allows(email)) {
      return const RegisterAttempt.failure(
        code: 'registration_email_not_allowed',
        message: '此邮箱不可用于注册',
        statusCode: 403,
      );
    }
    final handoff = registrationHandoff?.trim() ?? '';
    final verifiedByHandoff =
        handoff.isNotEmpty &&
        _tokens.verifyRegistrationHandoff(
              handoff,
              method: 'email',
              subject: email,
            ) !=
            null;
    if (!verifiedByHandoff &&
        !await _emailCodes.verifyRegisterCode(email, emailCode ?? '')) {
      return const RegisterAttempt.failure(
        code: 'invalid_email_code',
        message: '注册码无效或已过期。',
      );
    }
    if (await _users.findByEmail(email) != null) {
      return const RegisterAttempt.failure(
        code: 'email_already_registered',
        message: '该邮箱已注册。',
        statusCode: 409,
      );
    }

    final userId = _uuid.v4();
    final hash = await _passwords.hash(password);
    if (verifiedByHandoff) {
      final proof = _tokens.verifyRegistrationHandoff(
        handoff,
        method: 'email',
        subject: email,
      );
      if (proof == null ||
          !await _throttles.consumeOneTimeProof(
            proof.payload['jti']?.toString() ?? '',
          )) {
        return const RegisterAttempt.failure(
          code: 'invalid_registration_handoff',
          message: '注册验证已失效，请重新验证。',
        );
      }
    }
    await _users.createUser(
      userId: userId,
      email: email,
      nickname: nickname,
      passwordHash: hash,
    );
    final user = await _users.findById(userId);
    if (user == null) {
      return const RegisterAttempt.failure(
        code: 'register_failed',
        message: '注册失败，请稍后重试。',
        statusCode: 500,
      );
    }
    final auth = await _sessions.issueFirstPartyAuthResult(
      user,
      postRegistrationPasskeyBootstrap: true,
    );
    await _audit.log(
      action: 'user.register',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email},
      ip: requestIp,
    );
    return RegisterAttempt.success(auth);
  }

  Future<AdminLoginCodeAttempt> sendPhoneCode({
    required String phoneNumber,
    String? requestIp,
  }) async {
    final phones = _phones;
    if (phones == null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }
    final normalized = phones.normalizePhone(phoneNumber);
    if (normalized == null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }
    final sent = await phones.sendCode(
      phoneNumber: normalized,
      requestIp: requestIp?.trim() ?? '',
    );
    return sent.ok
        ? const AdminLoginCodeAttempt.success(message: '验证码已发送。')
        : AdminLoginCodeAttempt.failure(
            code: sent.code ?? 'temporary_issue',
            message: sent.message ?? '验证码发送失败，请稍后重试。',
            statusCode: sent.statusCode,
          );
  }

  Future<RegisterAttempt> registerWithPhone({
    required String phoneNumber,
    required String nickname,
    required String password,
    String? verifyCode,
    String? registrationHandoff,
    String? requestIp,
  }) async {
    final passwordFailure = _validatePassword(password);
    if (passwordFailure != null) {
      return passwordFailure;
    }
    final phones = _phones;
    if (phones == null) {
      return const RegisterAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }
    final normalized = phones.normalizePhone(phoneNumber);
    if (normalized == null) {
      return const RegisterAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }
    final handoff = registrationHandoff?.trim() ?? '';
    final proof = handoff.isEmpty
        ? null
        : _tokens.verifyRegistrationHandoff(
            handoff,
            method: 'phone',
            subject: normalized,
          );
    if (proof == null) {
      final checked = await phones.verifyCode(
        phoneNumber: normalized,
        verifyCode: verifyCode ?? '',
        requestIp: requestIp?.trim() ?? '',
      );
      if (!checked.ok) {
        return RegisterAttempt.failure(
          code: checked.code ?? 'invalid_verify_code',
          message: checked.message ?? '验证码无效或已过期。',
          statusCode: checked.statusCode,
        );
      }
    } else if (!await _throttles.consumeOneTimeProof(
      proof.payload['jti']?.toString() ?? '',
    )) {
      return const RegisterAttempt.failure(
        code: 'invalid_registration_handoff',
        message: '注册验证已失效，请重新验证。',
      );
    }
    if (await _users.findByPhoneNumber(normalized) != null) {
      return const RegisterAttempt.failure(
        code: 'phone_already_registered',
        message: '该手机号已注册。',
        statusCode: 409,
      );
    }

    final userId = _uuid.v4();
    final hash = await _passwords.hash(password);
    await _users.createUser(
      userId: userId,
      email: 'phone_$normalized@phone.local',
      nickname: nickname,
      passwordHash: hash,
      isEmailVerified: false,
    );
    await _users.updatePhoneNumber(userId: userId, phoneNumber: normalized);
    final user = await _users.findById(userId);
    if (user == null) {
      return const RegisterAttempt.failure(
        code: 'register_failed',
        message: '注册失败，请稍后重试。',
        statusCode: 500,
      );
    }
    final auth = await _sessions.issueFirstPartyAuthResult(
      user,
      postRegistrationPasskeyBootstrap: true,
    );
    return RegisterAttempt.success(auth);
  }

  RegisterAttempt? _validatePassword(String password) {
    final policy = _passwordPolicy.validate(password);
    return policy.ok
        ? null
        : RegisterAttempt.failure(
            code: 'password_policy_violation',
            message: policy.message!,
          );
  }

  Future<RegistrationEmailProviderPolicy> _emailProviderPolicy() {
    return _policy?.loadRegistrationEmailProviderPolicy() ??
        Future.value(
          const RegistrationEmailProviderPolicy(
            mode: SecurityPolicyService.blacklistMode,
            blacklist: <String>[],
            whitelist: <String>[],
          ),
        );
  }
}
