import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/token_service.dart';
import 'audit_service.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'authenticator_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'session_service.dart';
import 'webauthn_service.dart';

/// Owns password, email-code, phone-code, and authenticator login flows.
class LoginService {
  LoginService({
    required UserRepository userRepository,
    required SettingsRepository settingsRepository,
    required PasswordHasher passwordHasher,
    required TokenService tokenService,
    required EmailCodeService emailCodeService,
    required AuthThrottleService throttleService,
    required SessionService sessionService,
    required AuditService auditService,
    AuthenticatorService? authenticatorService,
    PhoneVerificationService? phoneVerificationService,
    WebAuthnService? webAuthnService,
  }) : _users = userRepository,
       _settings = settingsRepository,
       _passwords = passwordHasher,
       _tokens = tokenService,
       _emailCodes = emailCodeService,
       _throttles = throttleService,
       _sessions = sessionService,
       _audit = auditService,
       _authenticator = authenticatorService,
       _phones = phoneVerificationService,
       _webAuthn = webAuthnService;

  static const _loginEmailScope = 'verification-code:login:email';
  static const _loginIpScope = 'verification-code:login:ip';
  static const _loginCooldownScope = 'verification-code:login:cooldown:email';
  static const _mfaEmailScope = 'verification-code:mfa-login:email';
  static const _mfaIpScope = 'verification-code:mfa-login:ip';
  static const _mfaCooldownScope = 'verification-code:mfa-login:cooldown:email';
  static const _uniformEmailSendMessage = '登录验证码已发送，请检查邮箱。';
  static const _uniformPhoneSendMessage = '登录验证码已发送，请检查短信。';

  final UserRepository _users;
  final SettingsRepository _settings;
  final PasswordHasher _passwords;
  final TokenService _tokens;
  final EmailCodeService _emailCodes;
  final AuthThrottleService _throttles;
  final SessionService _sessions;
  final AuditService _audit;
  final AuthenticatorService? _authenticator;
  final PhoneVerificationService? _phones;
  final WebAuthnService? _webAuthn;

  Future<AdminLoginCodeAttempt> sendPasswordEmailCode({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceVerificationCodeSendGuards(
      email: email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _mfaEmailScope,
      ipScope: _mfaIpScope,
      cooldownScope: _mfaCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
    if (limited != null) {
      return limited;
    }
    final user = await _validPasswordUser(email, password);
    if (user == null) {
      return _passwordFailure;
    }
    await _emailCodes.issueLoginCode(
      user.email,
      templateName: user.roles.contains('admin')
          ? 'admin_login_verification'
          : 'login_verification',
    );
    await _throttles.startVerificationCodeCooldown(
      email: user.email,
      seconds: policy.adminLoginCodeCooldownSeconds,
      cooldownScope: _mfaCooldownScope,
    );
    return const AdminLoginCodeAttempt.success();
  }

  Future<AdminLoginCodeAttempt> sendPasswordPhoneCode({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    final user = await _validPasswordUser(email, password);
    if (user == null) {
      return _passwordFailure;
    }
    final phones = _phones;
    final phone = user.phoneNumber?.trim() ?? '';
    if (phones == null || phone.isEmpty || !user.isPhoneVerified) {
      return const AdminLoginCodeAttempt.failure(
        code: 'mfa_not_available',
        message: '当前账户未配置手机号验证。',
      );
    }
    final sent = await phones.sendCode(
      phoneNumber: phone,
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

  Future<PasswordLoginPreparation> preparePasswordLogin({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceLoginGuards(
      email: email,
      requestIp: requestIp,
      emailLimit: policy.loginEmailLimit,
      ipLimit: policy.loginIpLimit,
      window: Duration(seconds: policy.loginWindowSeconds),
      blockDuration: Duration(seconds: policy.loginBlockSeconds),
    );
    if (limited != null) {
      return PasswordLoginPreparation.failure(
        code: limited.code ?? 'rate_limited',
        message: limited.message ?? '请求过于频繁，请稍后再试。',
        statusCode: limited.statusCode,
      );
    }
    final user = await _validPasswordUser(email, password);
    if (user == null) {
      return const PasswordLoginPreparation.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
      );
    }
    if (await isBootstrapAdmin(user)) {
      return const PasswordLoginPreparation.success(
        factors: [],
        defaultFactor: null,
        directLogin: true,
      );
    }
    final factors = <String>['email_code'];
    if ((user.phoneNumber ?? '').trim().isNotEmpty && user.isPhoneVerified) {
      factors.insert(0, 'phone_code');
    }
    if (user.hasAuthenticator) {
      factors.add('authenticator');
    }
    if (_webAuthn != null && await _webAuthn.hasCredentials(user.id)) {
      factors.add('webauthn');
    }
    return PasswordLoginPreparation.success(
      factors: factors,
      defaultFactor: factors.first,
    );
  }

  Future<AdminLoginCodeAttempt> sendEmailCode({
    required String email,
    String? requestIp,
  }) async {
    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceVerificationCodeSendGuards(
      email: email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _loginEmailScope,
      ipScope: _loginIpScope,
      cooldownScope: _loginCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
    if (limited != null) {
      return limited;
    }
    try {
      await _emailCodes.issueLoginCode(
        email,
        templateName: 'login_verification',
      );
    } catch (_) {
      return const AdminLoginCodeAttempt.failure(
        code: 'temporary_issue',
        message: '邮件发送失败，请稍后重试。',
        statusCode: 503,
      );
    }
    await _throttles.startVerificationCodeCooldown(
      email: email,
      seconds: policy.loginCodeCooldownSeconds,
      cooldownScope: _loginCooldownScope,
    );
    return const AdminLoginCodeAttempt.success(
      message: _uniformEmailSendMessage,
    );
  }

  Future<LoginAttempt> loginWithPassword({
    required String email,
    required String password,
    String? factorType,
    String? emailCode,
    String? phoneCode,
    String? authenticatorCode,
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final limited = await _enforceLoginGuards(email, requestIp);
    if (limited != null) {
      return limited;
    }
    final user = await _validPasswordUser(email, password);
    if (user == null) {
      return _loginFailure;
    }
    if (await isBootstrapAdmin(user)) {
      return _completeLogin(
        user,
        factor: 'bootstrap_bypass',
        email: email,
        requestIp: requestIp,
        rememberMe: rememberMe,
      );
    }

    final factor = (factorType ?? 'email_code').trim();
    if (factor == 'email_code') {
      final code = emailCode?.trim() ?? '';
      if (code.isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '登录需要邮箱验证码。',
        );
      }
      final codeId = await _emailCodes.validateLoginCode(user.email, code);
      if (codeId == null) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '邮箱验证码无效或已过期。',
        );
      }
      final auth = await _sessions.issueFirstPartyAuthResult(
        user,
        rememberMe: rememberMe,
      );
      if (!await _emailCodes.consumeCode(codeId)) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '邮箱验证码无效或已过期。',
        );
      }
      await _finishLoginAudit(user, factor, email, requestIp);
      return LoginAttempt.success(auth);
    }
    if (factor == 'phone_code') {
      final code = phoneCode?.trim() ?? '';
      if (code.isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '登录需要手机验证码。',
        );
      }
      final phones = _phones;
      final phone = user.phoneNumber?.trim() ?? '';
      if (phones == null || phone.isEmpty || !user.isPhoneVerified) {
        return const LoginAttempt.failure(
          code: 'mfa_not_available',
          message: '当前账户未配置手机号验证。',
          statusCode: 400,
        );
      }
      final checked = await phones.verifyCode(
        phoneNumber: phone,
        verifyCode: code,
        requestIp: requestIp?.trim() ?? '',
      );
      if (!checked.ok) {
        return LoginAttempt.failure(
          code: checked.code ?? 'mfa_required',
          message: checked.message ?? '手机验证码无效或已过期。',
          statusCode: checked.statusCode,
        );
      }
    } else if (factor == 'authenticator') {
      final authenticator = _authenticator;
      final secret =
          (await _users.findAuthenticatorSecretByUserId(user.id))?.trim() ?? '';
      if (authenticator == null || secret.isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_not_available',
          message: '当前账户未配置 Authenticator 验证器。',
          statusCode: 400,
        );
      }
      final code = authenticatorCode?.trim() ?? '';
      if (code.isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '请输入 Authenticator 动态验证码。',
        );
      }
      if (!authenticator.verifyCode(secret: secret, code: code)) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: 'Authenticator 动态验证码无效。',
        );
      }
    } else {
      return const LoginAttempt.failure(
        code: 'invalid_factor',
        message: '不支持的验证因子。',
        statusCode: 400,
      );
    }
    return _completeLogin(
      user,
      factor: factor,
      email: email,
      requestIp: requestIp,
      rememberMe: rememberMe,
    );
  }

  Future<LoginAttempt> loginWithEmailCode({
    required String email,
    required String emailCode,
    String? password,
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final limited = await _enforceLoginGuards(email, requestIp);
    if (limited != null) {
      return limited;
    }
    final codeId = await _emailCodes.validateLoginCode(email, emailCode.trim());
    if (codeId == null) {
      return const LoginAttempt.failure(
        code: 'mfa_required',
        message: '邮箱验证码无效或已过期。',
      );
    }
    final user = await _users.findByEmail(email);
    if (user == null) {
      if (!await _emailCodes.consumeCode(codeId)) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '邮箱验证码无效或已过期。',
        );
      }
      return LoginAttempt.registrationRequired(
        _tokens.issueRegistrationHandoff(method: 'email', subject: email),
      );
    }
    if (user.isBanned) return _bannedFailure;
    if (await isBootstrapAdmin(user)) {
      return _loginFailure;
    }
    if (user.roles.contains('admin')) {
      final legacyPassword = password?.trim() ?? '';
      if (legacyPassword.isEmpty) {
        if (!await _emailCodes.consumeCode(codeId)) {
          return _loginFailure;
        }
        return LoginAttempt.mfaRequired(
          stepUpChallenge: _tokens.issueLoginStepUpChallenge(
            userId: user.id,
            primaryMethod: 'email_code',
          ),
          factors: await _secondaryFactors(user, 'email_code'),
        );
      }
      if (!await _passwords.verify(user.passwordHash, legacyPassword)) {
        return _loginFailure;
      }
    }
    if (!await _emailCodes.consumeCode(codeId)) {
      return const LoginAttempt.failure(
        code: 'mfa_required',
        message: '邮箱验证码无效或已过期。',
      );
    }
    final auth = await _sessions.issueFirstPartyAuthResult(
      user,
      rememberMe: rememberMe,
    );
    await _throttles.clearLoginGuards(email: email);
    await _audit.log(
      action: 'user.login.email_code',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email, 'email_code_login': true},
      ip: requestIp,
    );
    return LoginAttempt.success(auth);
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
    try {
      final sent = await phones.sendCode(
        phoneNumber: normalized,
        requestIp: requestIp?.trim() ?? '',
      );
      if (!sent.ok) {
        return AdminLoginCodeAttempt.failure(
          code: sent.code ?? 'temporary_issue',
          message: sent.message ?? '验证码发送失败，请稍后重试。',
          statusCode: sent.statusCode,
        );
      }
    } catch (_) {
      return const AdminLoginCodeAttempt.failure(
        code: 'temporary_issue',
        message: '验证码发送失败，请稍后重试。',
        statusCode: 503,
      );
    }
    return const AdminLoginCodeAttempt.success(
      message: _uniformPhoneSendMessage,
    );
  }

  Future<void> _recordDeliveryFailure(
    UserRecord user, {
    required String channel,
    String? requestIp,
  }) async {
    try {
      await _audit.log(
        action: 'user.login_code.delivery_failed',
        actorId: user.id,
        actorType: 'user',
        resourceType: 'user',
        resourceId: user.id,
        metadata: {'channel': channel},
        ip: requestIp,
      );
    } catch (_) {
      // Delivery privacy must not depend on the audit sink being available.
    }
  }

  Future<LoginAttempt> loginWithPhoneCode({
    required String phoneNumber,
    required String verifyCode,
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final phones = _phones;
    if (phones == null) {
      return const LoginAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }
    final normalized = phones.normalizePhone(phoneNumber);
    if (normalized == null) {
      return const LoginAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }
    final checked = await phones.verifyCode(
      phoneNumber: normalized,
      verifyCode: verifyCode,
      requestIp: requestIp?.trim() ?? '',
    );
    if (!checked.ok) {
      return LoginAttempt.failure(
        code: checked.code ?? 'mfa_required',
        message: checked.message ?? '手机验证码无效或已过期。',
        statusCode: checked.statusCode,
      );
    }
    final user = await _users.findByPhoneNumber(normalized);
    if (user == null) {
      return LoginAttempt.registrationRequired(
        _tokens.issueRegistrationHandoff(method: 'phone', subject: normalized),
      );
    }
    if (user.isBanned) return _bannedFailure;
    if (user.roles.contains('admin')) {
      return LoginAttempt.mfaRequired(
        stepUpChallenge: _tokens.issueLoginStepUpChallenge(
          userId: user.id,
          primaryMethod: 'phone_code',
        ),
        factors: await _secondaryFactors(user, 'phone_code'),
      );
    }
    final auth = await _sessions.issueFirstPartyAuthResult(
      user,
      rememberMe: rememberMe,
    );
    await _audit.log(
      action: 'user.login.phone_code',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email, 'phone_code_login': true},
      ip: requestIp,
    );
    return LoginAttempt.success(auth);
  }

  Future<AdminLoginCodeAttempt> sendLoginStepUpCode({
    required String challenge,
    required String factor,
    String? requestIp,
  }) async {
    final context = await _stepUpContext(challenge, factor);
    if (context == null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'invalid_challenge',
        message: '登录验证已失效，请重新开始。',
        statusCode: 401,
      );
    }
    final user = context.user;
    if (factor == 'email_code') {
      final policy = await _throttles.loadPolicy();
      final limited = await _throttles.enforceVerificationCodeSendGuards(
        email: user.email,
        requestIp: requestIp,
        policy: policy,
        emailScope: _mfaEmailScope,
        ipScope: _mfaIpScope,
        cooldownScope: _mfaCooldownScope,
        emailLimit: policy.adminLoginCodeEmailLimit,
        ipLimit: policy.adminLoginCodeIpLimit,
      );
      if (limited != null) return limited;
      try {
        await _emailCodes.issueStepUpCode(user.email);
      } catch (_) {
        await _recordDeliveryFailure(
          user,
          channel: 'email',
          requestIp: requestIp,
        );
        return const AdminLoginCodeAttempt.failure(
          code: 'temporary_issue',
          message: '邮件发送失败，请稍后重试。',
          statusCode: 503,
        );
      }
      await _throttles.startVerificationCodeCooldown(
        email: user.email,
        seconds: policy.adminLoginCodeCooldownSeconds,
        cooldownScope: _mfaCooldownScope,
      );
      return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
    }
    if (factor == 'phone_code') {
      final phone = user.phoneNumber?.trim() ?? '';
      PhoneVerificationAttempt? sent;
      try {
        sent = await _phones?.sendCode(
          phoneNumber: phone,
          requestIp: requestIp?.trim() ?? '',
        );
      } catch (_) {
        await _recordDeliveryFailure(
          user,
          channel: 'phone',
          requestIp: requestIp,
        );
      }
      return sent?.ok == true
          ? const AdminLoginCodeAttempt.success(message: '验证码已发送。')
          : AdminLoginCodeAttempt.failure(
              code: sent?.code ?? 'temporary_issue',
              message: sent?.message ?? '验证码发送失败，请稍后重试。',
              statusCode: sent?.statusCode ?? 503,
            );
    }
    return const AdminLoginCodeAttempt.failure(
      code: 'invalid_factor',
      message: '该验证方式不需要发送验证码。',
    );
  }

  Future<Map<String, dynamic>?> beginLoginStepUpPasskey({
    required String challenge,
    required String origin,
  }) async {
    final context = await _stepUpContext(challenge, 'webauthn');
    if (context == null) return null;
    return _webAuthn?.generateAuthenticationOptions(
      email: context.user.email,
      userId: context.user.id,
      origin: origin,
      requireUserVerification: true,
    );
  }

  Future<LoginAttempt> completeLoginStepUp({
    required String challenge,
    required String factor,
    required Map<String, dynamic> proof,
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final context = await _stepUpContext(challenge, factor);
    if (context == null) return _loginFailure;
    final user = context.user;
    var verified = false;
    if (factor == 'password') {
      verified = await _passwords.verify(
        user.passwordHash,
        (proof['password'] ?? '').toString(),
      );
    } else if (factor == 'email_code') {
      verified = await _emailCodes.verifyStepUpCode(
        user.email,
        (proof['code'] ?? '').toString().trim(),
      );
    } else if (factor == 'phone_code') {
      final checked = await _phones?.verifyCode(
        phoneNumber: user.phoneNumber?.trim() ?? '',
        verifyCode: (proof['code'] ?? '').toString().trim(),
        requestIp: requestIp?.trim() ?? '',
      );
      verified = checked?.ok == true;
    } else if (factor == 'authenticator') {
      final secret = await _users.findAuthenticatorSecretByUserId(user.id);
      verified =
          secret != null &&
          (_authenticator?.verifyCode(
                secret: secret,
                code: (proof['code'] ?? '').toString().trim(),
              ) ??
              false);
    } else if (factor == 'webauthn' && proof['response'] is Map) {
      verified =
          await (_webAuthn?.verifyAuthentication(
                userId: user.id,
                email: user.email,
                response: Map<String, dynamic>.from(proof['response'] as Map),
                forceUserVerification: true,
              ) ??
              Future.value(false));
    }
    if (!verified || !await _throttles.consumeOneTimeProof(context.proofId)) {
      return const LoginAttempt.failure(
        code: 'verification_failed',
        message: '二次验证未通过，请重试。',
      );
    }
    return _completeLogin(
      user,
      factor: '${context.primaryMethod}+$factor',
      email: user.email,
      requestIp: requestIp,
      rememberMe: rememberMe,
    );
  }

  Future<_LoginStepUpContext?> _stepUpContext(
    String challenge,
    String factor,
  ) async {
    final verified = _tokens.verifyLoginStepUpChallenge(challenge);
    if (verified == null) return null;
    final userId = verified.payload['sub']?.toString() ?? '';
    final primary = verified.payload['primary_method']?.toString() ?? '';
    final proofId = verified.payload['jti']?.toString() ?? '';
    final user = await _users.findById(userId);
    if (user == null || proofId.isEmpty) return null;
    final factors = await _secondaryFactors(user, primary);
    return factors.contains(factor)
        ? _LoginStepUpContext(
            user: user,
            primaryMethod: primary,
            proofId: proofId,
          )
        : null;
  }

  Future<List<String>> _secondaryFactors(
    UserRecord user,
    String primaryMethod,
  ) async {
    return [
      'password',
      if (primaryMethod != 'email_code' && user.isEmailVerified) 'email_code',
      if (primaryMethod != 'phone_code' &&
          user.isPhoneVerified &&
          (user.phoneNumber?.trim().isNotEmpty ?? false))
        'phone_code',
      if (user.hasAuthenticator) 'authenticator',
      if (await (_webAuthn?.hasCredentials(user.id) ?? Future.value(false)))
        'webauthn',
    ];
  }

  Future<UserRecord?> _validPasswordUser(String email, String password) async {
    final user = await _users.findByEmail(email);
    if (user == null || !await _passwords.verify(user.passwordHash, password)) {
      return null;
    }
    return user;
  }

  Future<LoginAttempt?> _enforceLoginGuards(String email, String? ip) async {
    final policy = await _throttles.loadPolicy();
    return _throttles.enforceLoginGuards(
      email: email,
      requestIp: ip,
      emailLimit: policy.loginEmailLimit,
      ipLimit: policy.loginIpLimit,
      window: Duration(seconds: policy.loginWindowSeconds),
      blockDuration: Duration(seconds: policy.loginBlockSeconds),
    );
  }

  Future<LoginAttempt> _completeLogin(
    UserRecord user, {
    required String factor,
    required String email,
    required String? requestIp,
    required bool rememberMe,
  }) async {
    if (user.isBanned) return _bannedFailure;
    final auth = await _sessions.issueFirstPartyAuthResult(
      user,
      rememberMe: rememberMe,
    );
    await _finishLoginAudit(user, factor, email, requestIp);
    return LoginAttempt.success(auth);
  }

  Future<void> _finishLoginAudit(
    UserRecord user,
    String factor,
    String email,
    String? ip,
  ) async {
    await _throttles.clearLoginGuards(email: email);
    await _audit.log(
      action: 'user.login',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email, 'factor_type': factor},
      ip: ip,
    );
  }

  Future<bool> isBootstrapAdmin(UserRecord user) async {
    return user.roles.contains('admin') &&
        user.email.trim().toLowerCase().endsWith('@rosm.local') &&
        await _settings.isBootstrapLoginEnabled();
  }

  static const _passwordFailure = AdminLoginCodeAttempt.failure(
    code: 'login_failed',
    message: '账号或密码错误。',
    statusCode: 401,
  );
  static const _loginFailure = LoginAttempt.failure(
    code: 'login_failed',
    message: '登录失败。',
    statusCode: 401,
  );
  static const _bannedFailure = LoginAttempt.failure(
    code: 'account_banned',
    message: '该账户已被封禁。如需申诉，请联系 info@rosemaryisland.pro。',
    statusCode: 403,
  );
}

class _LoginStepUpContext {
  const _LoginStepUpContext({
    required this.user,
    required this.primaryMethod,
    required this.proofId,
  });

  final UserRecord user;
  final String primaryMethod;
  final String proofId;
}
