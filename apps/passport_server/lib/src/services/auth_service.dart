import 'package:uuid/uuid.dart';

import '../models/authenticated_user.dart';
import '../repositories/oidc_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/token_service.dart';
import 'audit_service.dart';
import 'authenticator_service.dart';
import 'captcha_service.dart';
import 'email_code_service.dart';
import 'security_policy_service.dart';
import 'security_service.dart';
import 'token_validation_service.dart';
import 'webauthn_service.dart';

class AuthResult {
  const AuthResult({
    required this.user,
    required this.tokens,
    this.postRegistrationPasskeyBootstrap = false,
  });

  final AuthenticatedUser user;
  final TokenPair tokens;
  final bool postRegistrationPasskeyBootstrap;
}

class LoginAttempt {
  const LoginAttempt.success(this.result)
    : code = null,
      message = null,
      statusCode = 200;

  const LoginAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 401,
  }) : result = null;

  final AuthResult? result;
  final String? code;
  final String? message;
  final int statusCode;

  bool get ok => result != null;
}

class PasswordLoginPreparation {
  const PasswordLoginPreparation.success({
    required this.factors,
    required this.defaultFactor,
    this.directLogin = false,
  }) : ok = true,
       code = null,
       message = null,
       statusCode = 200;

  const PasswordLoginPreparation.failure({
    required this.code,
    required this.message,
    this.statusCode = 401,
  }) : ok = false,
       factors = const [],
       defaultFactor = null,
       directLogin = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final List<String> factors;
  final String? defaultFactor;
  final bool directLogin;
}

class AdminLoginCodeAttempt {
  const AdminLoginCodeAttempt.success({
    this.message,
    this.requiresBinding = false,
  }) : ok = true,
       code = null,
       statusCode = 200;

  const AdminLoginCodeAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       requiresBinding = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final bool requiresBinding;
}

class RegisterAttempt {
  const RegisterAttempt.success(this.result)
    : ok = true,
      code = null,
      message = null,
      statusCode = 201;

  const RegisterAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       result = null;

  final bool ok;
  final AuthResult? result;
  final String? code;
  final String? message;
  final int statusCode;
}

class AccountUpdateAttempt {
  const AccountUpdateAttempt.success({
    required this.updatedEmail,
    required this.updatedPassword,
    required this.updatedNickname,
  }) : ok = true,
       code = null,
       message = null,
       statusCode = 200;

  const AccountUpdateAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       updatedEmail = false,
       updatedPassword = false,
       updatedNickname = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final bool updatedEmail;
  final bool updatedPassword;
  final bool updatedNickname;
}

class EmailActionAttempt {
  const EmailActionAttempt.success({this.message})
    : ok = true,
      code = null,
      statusCode = 200;

  const EmailActionAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
}

class CredentialActionAttempt {
  const CredentialActionAttempt.success({this.message})
    : ok = true,
      code = null,
      statusCode = 200;

  const CredentialActionAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
}

class _CredentialLimitException implements Exception {
  const _CredentialLimitException();
}

class AuthService {
  static const _postRegistrationPasskeyBootstrapSeconds = 600;

  AuthService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required TokenService tokenService,
    required TokenValidationService tokenValidationService,
    required EmailCodeService emailCodeService,
    required CaptchaService captchaService,
    required OidcRepository oidcRepository,
    required SettingsRepository settingsRepository,
    required AuditService auditService,
    SecurityService? securityService,
    SecurityPolicyService? securityPolicyService,
    AuthenticatorService? authenticatorService,
    WebAuthnService? webAuthnService,
  }) : _users = userRepository,
       _passwordHasher = passwordHasher,
       _tokenService = tokenService,
       _tokenValidation = tokenValidationService,
       _emailCodeService = emailCodeService,
       _captchaService = captchaService,
       _oidcRepository = oidcRepository,
       _settings = settingsRepository,
       _audit = auditService,
       _security = securityService,
       _policy = securityPolicyService,
       _authenticator = authenticatorService,
       _webAuthn = webAuthnService;

  final UserRepository _users;
  final PasswordHasher _passwordHasher;
  final TokenService _tokenService;
  final TokenValidationService _tokenValidation;
  final EmailCodeService _emailCodeService;
  final CaptchaService _captchaService;
  final OidcRepository _oidcRepository;
  final SettingsRepository _settings;
  final AuditService _audit;
  final SecurityService? _security;
  final SecurityPolicyService? _policy;
  final AuthenticatorService? _authenticator;
  final WebAuthnService? _webAuthn;
  final _uuid = const Uuid();
  static const _verificationCodeRegisterEmailScope =
      'verification-code:register:email';
  static const _verificationCodeRegisterIpScope =
      'verification-code:register:ip';
  static const _verificationCodeRegisterCooldownScope =
      'verification-code:register:cooldown:email';
  static const _verificationCodeLoginEmailScope =
      'verification-code:login:email';
  static const _verificationCodeLoginIpScope =
      'verification-code:login:ip';
  static const _verificationCodeLoginCooldownScope =
      'verification-code:login:cooldown:email';
  static const _verificationCodeMfaEmailScope =
      'verification-code:mfa-login:email';
  static const _verificationCodeMfaIpScope =
      'verification-code:mfa-login:ip';
  static const _verificationCodeMfaCooldownScope =
      'verification-code:mfa-login:cooldown:email';
  static const _verificationCodeBindEmailScope =
      'verification-code:bind-email:email';
  static const _verificationCodeBindIpScope =
      'verification-code:bind-email:ip';
  static const _verificationCodeBindCooldownScope =
      'verification-code:bind-email:cooldown:email';
  static const _verificationCodeResetEmailScope =
      'verification-code:password-reset:email';
  static const _verificationCodeResetIpScope =
      'verification-code:password-reset:ip';
  static const _verificationCodeResetCooldownScope =
      'verification-code:password-reset:cooldown:email';
  static const _maxWebAuthnCredentials = 5;

  Future<bool> verifyCaptcha(String token, {String? ip}) {
    return _captchaService.verifyCaptchaToken(token, remoteIp: ip);
  }

  Future<bool> shouldBypassBootstrapCaptcha({
    required String email,
    required String password,
  }) async {
    final user = await _users.findByEmail(email);
    if (user == null) {
      return false;
    }
    final passwordValid = await _passwordHasher.verify(
      user.passwordHash,
      password,
    );
    if (!passwordValid) {
      return false;
    }
    return isBootstrapAdmin(user);
  }

  Future<bool> shouldBypassBootstrapCaptchaForUser(String userId) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return false;
    }
    return isBootstrapAdmin(user);
  }

  Future<AdminLoginCodeAttempt> sendRegisterCode({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final emailProviderPolicy = _policy == null
        ? const RegistrationEmailProviderPolicy(
            mode: SecurityPolicyService.blacklistMode,
            blacklist: <String>[],
            whitelist: <String>[],
          )
        : await _policy.loadRegistrationEmailProviderPolicy();
    if (!emailProviderPolicy.allows(email)) {
      return AdminLoginCodeAttempt.failure(
        code: 'registration_email_not_allowed',
        message: '此邮箱不可用于注册',
        statusCode: 403,
      );
    }
    final limited = await _enforceVerificationCodeSendGuards(
      email: email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _verificationCodeRegisterEmailScope,
      ipScope: _verificationCodeRegisterIpScope,
      cooldownScope: _verificationCodeRegisterCooldownScope,
      emailLimit: policy.registerCodeEmailLimit,
      ipLimit: policy.registerCodeIpLimit,
    );
    if (limited != null) {
      return limited;
    }

    await _emailCodeService.issueRegisterCode(email);
    await _startVerificationCodeCooldown(
      email: email,
      seconds: policy.registerCodeCooldownSeconds,
      cooldownScope: _verificationCodeRegisterCooldownScope,
    );
    return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
  }

  Future<int?> loginRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final emailRetry = policy.emailRateLimitEnabled
        ? await security.retryAfterSeconds(
            scope: 'login:email',
            subject: normalizedEmail,
          )
        : null;
    final ipSubject = _subjectOrEmpty(requestIp);
    final ipRetry = ipSubject.isEmpty || !policy.ipRateLimitEnabled
        ? null
        : await security.retryAfterSeconds(
            scope: 'login:ip',
            subject: ipSubject,
          );
    return _maxRetryAfter(emailRetry, ipRetry);
  }

  Future<int?> adminCodeRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    return verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: _verificationCodeMfaEmailScope,
      ipScope: _verificationCodeMfaIpScope,
      cooldownScope: _verificationCodeMfaCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
  }

  Future<int?> verificationCodeRetryAfter({
    required String email,
    String? requestIp,
    required String emailScope,
    required String ipScope,
    required String cooldownScope,
    required int emailLimit,
    required int ipLimit,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final emailRetry = policy.emailRateLimitEnabled && emailLimit > 0
        ? await security.retryAfterSeconds(
            scope: emailScope,
            subject: normalizedEmail,
          )
        : null;
    final ipSubject = _subjectOrEmpty(requestIp);
    final ipRetry = ipSubject.isEmpty || !policy.ipRateLimitEnabled || ipLimit < 1
        ? null
        : await security.retryAfterSeconds(
            scope: ipScope,
            subject: ipSubject,
          );
    final cooldownRetry = await verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: cooldownScope,
    );
    return _maxRetryAfter(_maxRetryAfter(emailRetry, ipRetry), cooldownRetry);
  }

  Future<int?> verificationCodeCooldownRetryAfter({
    required String email,
    required String cooldownScope,
  }) async {
    final security = _security;
    if (security == null) {
      return null;
    }
    return security.retryAfterSeconds(
      scope: cooldownScope,
      subject: email.trim().toLowerCase(),
    );
  }

  Future<int?> loginCodeCooldownRetryAfter({required String email}) {
    return verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: _verificationCodeLoginCooldownScope,
    );
  }

  Future<int?> mfaLoginCodeCooldownRetryAfter({required String email}) {
    return verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: _verificationCodeMfaCooldownScope,
    );
  }

  Future<int?> loginCodeSendRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    return verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: _verificationCodeLoginEmailScope,
      ipScope: _verificationCodeLoginIpScope,
      cooldownScope: _verificationCodeLoginCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
  }

  Future<int?> mfaLoginCodeSendRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    return verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: _verificationCodeMfaEmailScope,
      ipScope: _verificationCodeMfaIpScope,
      cooldownScope: _verificationCodeMfaCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
  }

  Future<int?> registerCodeRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    return verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: _verificationCodeRegisterEmailScope,
      ipScope: _verificationCodeRegisterIpScope,
      cooldownScope: _verificationCodeRegisterCooldownScope,
      emailLimit: policy.registerCodeEmailLimit,
      ipLimit: policy.registerCodeIpLimit,
    );
  }

  Future<int?> bindEmailCodeRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    return verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: _verificationCodeBindEmailScope,
      ipScope: _verificationCodeBindIpScope,
      cooldownScope: _verificationCodeBindCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
  }

  Future<int?> bindEmailCodeCooldownRetryAfter({required String email}) {
    return verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: _verificationCodeBindCooldownScope,
    );
  }

  Future<int?> passwordResetCodeRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    return verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: _verificationCodeResetEmailScope,
      ipScope: _verificationCodeResetIpScope,
      cooldownScope: _verificationCodeResetCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
  }

  Future<int?> passwordResetCodeCooldownRetryAfter({required String email}) {
    return verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: _verificationCodeResetCooldownScope,
    );
  }

  Future<int?> refreshRetryAfter({String? requestIp}) async {
    final ipSubject = _subjectOrEmpty(requestIp);
    if (ipSubject.isEmpty) {
      return null;
    }
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    if (!policy.ipRateLimitEnabled) {
      return null;
    }
    return security.retryAfterSeconds(
      scope: 'refresh:first-party:ip',
      subject: ipSubject,
    );
  }

  Future<AdminLoginCodeAttempt> sendLoginCode({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final loginCodeLimited = await _enforceVerificationCodeSendGuards(
      email: email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _verificationCodeMfaEmailScope,
      ipScope: _verificationCodeMfaIpScope,
      cooldownScope: _verificationCodeMfaCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
    if (loginCodeLimited != null) {
      return loginCodeLimited;
    }

    final user = await _users.findByEmail(email);
    if (user == null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
        statusCode: 401,
      );
    }

    final passwordValid = await _passwordHasher.verify(
      user.passwordHash,
      password,
    );
    if (!passwordValid) {
      return const AdminLoginCodeAttempt.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
        statusCode: 401,
      );
    }

    await _emailCodeService.issueLoginCode(
      user.email,
      templateName: user.roles.contains('admin')
          ? 'admin_login_verification'
          : 'login_verification',
    );
    await _startVerificationCodeCooldown(
      email: user.email,
      seconds: policy.adminLoginCodeCooldownSeconds,
      cooldownScope: _verificationCodeMfaCooldownScope,
    );
    return const AdminLoginCodeAttempt.success();
  }

  Future<PasswordLoginPreparation> preparePasswordLogin({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final limited = await _enforceLoginGuards(
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

    final user = await _users.findByEmail(email);
    if (user == null) {
      return const PasswordLoginPreparation.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
        statusCode: 401,
      );
    }

    final passwordValid = await _passwordHasher.verify(
      user.passwordHash,
      password,
    );
    if (!passwordValid) {
      return const PasswordLoginPreparation.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
        statusCode: 401,
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
    if (user.hasAuthenticator) {
      factors.add('authenticator');
    }
    final webAuthn = _webAuthn;
    if (webAuthn != null && await webAuthn.hasCredentials(user.id)) {
      factors.add('webauthn');
    }

    return PasswordLoginPreparation.success(
      factors: factors,
      defaultFactor: factors.first,
    );
  }

  Future<AdminLoginCodeAttempt> sendEmailLoginCode({
    required String email,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final loginCodeLimited = await _enforceVerificationCodeSendGuards(
      email: email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _verificationCodeLoginEmailScope,
      ipScope: _verificationCodeLoginIpScope,
      cooldownScope: _verificationCodeLoginCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
    if (loginCodeLimited != null) {
      return loginCodeLimited;
    }

    final user = await _users.findByEmail(email);
    if (user != null && !user.roles.contains('admin')) {
      await _emailCodeService.issueLoginCode(
        user.email,
        templateName: 'login_verification',
      );
    }
    await _startVerificationCodeCooldown(
      email: email,
      seconds: policy.loginCodeCooldownSeconds,
      cooldownScope: _verificationCodeLoginCooldownScope,
    );
    return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
  }

  Future<AdminLoginCodeAttempt> sendAdminLoginCode({
    required String email,
    required String password,
    String? requestIp,
  }) {
    return sendLoginCode(
      email: email,
      password: password,
      requestIp: requestIp,
    );
  }

  Future<RegisterAttempt> register({
    required String email,
    required String nickname,
    required String password,
    required String emailCode,
    String? requestIp,
  }) async {
    final emailProviderPolicy = _policy == null
        ? const RegistrationEmailProviderPolicy(
            mode: SecurityPolicyService.blacklistMode,
            blacklist: <String>[],
            whitelist: <String>[],
          )
        : await _policy.loadRegistrationEmailProviderPolicy();
    if (!emailProviderPolicy.allows(email)) {
      return RegisterAttempt.failure(
        code: 'registration_email_not_allowed',
        message: '此邮箱不可用于注册',
        statusCode: 403,
      );
    }

    final alreadyExists = await _users.findByEmail(email);
    if (alreadyExists != null) {
      return const RegisterAttempt.failure(
        code: 'email_already_registered',
        message: '该邮箱已注册。',
        statusCode: 409,
      );
    }

    final codeValid = await _emailCodeService.verifyRegisterCode(
      email,
      emailCode,
    );
    if (!codeValid) {
      return const RegisterAttempt.failure(
        code: 'invalid_email_code',
        message: '注册码无效或已过期。',
        statusCode: 400,
      );
    }

    final userId = _uuid.v4();
    final passwordHash = await _passwordHasher.hash(password);

    await _users.createUser(
      userId: userId,
      email: email,
      nickname: nickname,
      passwordHash: passwordHash,
    );

    final userRecord = await _users.findById(userId);
    if (userRecord == null) {
      return const RegisterAttempt.failure(
        code: 'register_failed',
        message: '注册失败，请稍后重试。',
        statusCode: 500,
      );
    }

    final authResult = await _issueFirstPartyAuthResult(
      userRecord,
      postRegistrationPasskeyBootstrap: true,
    );

    await _audit.log(
      action: 'user.register',
      actorId: userRecord.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: userRecord.id,
      metadata: {'email': userRecord.email},
      ip: requestIp,
    );

    return RegisterAttempt.success(authResult);
  }

  Future<LoginAttempt> login({
    required String email,
    required String password,
    String? factorType,
    String? emailCode,
    String? authenticatorCode,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final limited = await _enforceLoginGuards(
      email: email,
      requestIp: requestIp,
      emailLimit: policy.loginEmailLimit,
      ipLimit: policy.loginIpLimit,
      window: Duration(seconds: policy.loginWindowSeconds),
      blockDuration: Duration(seconds: policy.loginBlockSeconds),
    );
    if (limited != null) {
      return limited;
    }

    final user = await _users.findByEmail(email);
    if (user == null) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
        statusCode: 401,
      );
    }

    final passwordValid = await _passwordHasher.verify(
      user.passwordHash,
      password,
    );
    if (!passwordValid) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '账号或密码错误。',
        statusCode: 401,
      );
    }

    if (await isBootstrapAdmin(user)) {
      final authResult = await _issueFirstPartyAuthResult(user);
      await _clearLoginGuards(email: email);
      await _audit.log(
        action: 'user.login',
        actorId: user.id,
        actorType: 'user',
        resourceType: 'user',
        resourceId: user.id,
        metadata: {'email': user.email, 'factor_type': 'bootstrap_bypass'},
        ip: requestIp,
      );
      return LoginAttempt.success(authResult);
    }

    final normalizedFactor = (factorType ?? 'email_code').trim();
    if (normalizedFactor == 'email_code') {
      if (emailCode == null || emailCode.trim().isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '登录需要邮箱验证码。',
          statusCode: 401,
        );
      }
      final codeId = await _emailCodeService.validateLoginCode(
        user.email,
        emailCode.trim(),
      );
      if (codeId == null) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '邮箱验证码无效或已过期。',
          statusCode: 401,
        );
      }
      final authResult = await _issueFirstPartyAuthResult(user);
      final consumed = await _emailCodeService.consumeCode(codeId);
      if (!consumed) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '邮箱验证码无效或已过期。',
          statusCode: 401,
        );
      }
      await _clearLoginGuards(email: email);

      await _audit.log(
        action: 'user.login',
        actorId: user.id,
        actorType: 'user',
        resourceType: 'user',
        resourceId: user.id,
        metadata: {'email': user.email, 'factor_type': normalizedFactor},
        ip: requestIp,
      );

      return LoginAttempt.success(authResult);
    } else if (normalizedFactor == 'authenticator') {
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
      if (authenticatorCode == null || authenticatorCode.trim().isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '请输入 Authenticator 动态验证码。',
          statusCode: 401,
        );
      }
      final verified = authenticator.verifyCode(
        secret: secret,
        code: authenticatorCode.trim(),
      );
      if (!verified) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: 'Authenticator 动态验证码无效。',
          statusCode: 401,
        );
      }
    } else {
      return const LoginAttempt.failure(
        code: 'invalid_factor',
        message: '不支持的验证因子。',
        statusCode: 400,
      );
    }

    final authResult = await _issueFirstPartyAuthResult(user);
    await _clearLoginGuards(email: email);

    await _audit.log(
      action: 'user.login',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email, 'factor_type': normalizedFactor},
      ip: requestIp,
    );

    return LoginAttempt.success(authResult);
  }

  Future<LoginAttempt> loginWithEmailCode({
    required String email,
    required String emailCode,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final limited = await _enforceLoginGuards(
      email: email,
      requestIp: requestIp,
      emailLimit: policy.loginEmailLimit,
      ipLimit: policy.loginIpLimit,
      window: Duration(seconds: policy.loginWindowSeconds),
      blockDuration: Duration(seconds: policy.loginBlockSeconds),
    );
    if (limited != null) {
      return limited;
    }

    final user = await _users.findByEmail(email);
    if (user == null || user.roles.contains('admin')) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '登录失败。',
        statusCode: 401,
      );
    }

    final codeId = await _emailCodeService.validateLoginCode(
      user.email,
      emailCode.trim(),
    );
    if (codeId == null) {
      return const LoginAttempt.failure(
        code: 'mfa_required',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }

    final authResult = await _issueFirstPartyAuthResult(user);
    final consumed = await _emailCodeService.consumeCode(codeId);
    if (!consumed) {
      return const LoginAttempt.failure(
        code: 'mfa_required',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }
    await _clearLoginGuards(email: email);

    await _audit.log(
      action: 'user.login.email_code',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email, 'email_code_login': true},
      ip: requestIp,
    );

    return LoginAttempt.success(authResult);
  }

  Future<AccountUpdateAttempt> updateSelfAccount({
    required String userId,
    required String currentPassword,
    String? nickname,
    String? newEmail,
    String? newPassword,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const AccountUpdateAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }

    var updatedEmail = false;
    var updatedPassword = false;
    var updatedNickname = false;

    if (nickname != null && nickname.trim().isNotEmpty) {
      await _users.updateNickname(userId: user.id, nickname: nickname.trim());
      updatedNickname = true;
    }

    final hasSensitiveChange =
        (newEmail != null && newEmail.trim().isNotEmpty) ||
        (newPassword != null && newPassword.trim().isNotEmpty);
    if (!hasSensitiveChange) {
      return AccountUpdateAttempt.success(
        updatedEmail: updatedEmail,
        updatedPassword: updatedPassword,
        updatedNickname: updatedNickname,
      );
    }

    if (currentPassword.isEmpty) {
      return const AccountUpdateAttempt.failure(
        code: 'invalid_request',
        message: 'current_password is required.',
      );
    }

    final valid = await _passwordHasher.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      return const AccountUpdateAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }

    if (newEmail != null && newEmail.trim().isNotEmpty) {
      final targetEmail = newEmail.trim().toLowerCase();
      if (user.roles.contains('admin') &&
          _isReservedBootstrapEmail(targetEmail)) {
        return const AccountUpdateAttempt.failure(
          code: 'invalid_email',
          message: '管理员邮箱不能使用保留的本地域名。',
        );
      }
      final existing = await _users.findByEmail(targetEmail);
      if (existing != null && existing.id != user.id) {
        return const AccountUpdateAttempt.failure(
          code: 'email_exists',
          message: '邮箱已被占用。',
          statusCode: 409,
        );
      }
      await _users.updateEmail(userId: user.id, email: targetEmail);
      updatedEmail = true;
    }

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      final passwordHash = await _passwordHasher.hash(newPassword.trim());
      await _users.updatePasswordHash(
        userId: user.id,
        passwordHash: passwordHash,
      );
      updatedPassword = true;
    }

    if (updatedEmail || updatedPassword) {
      await _revokeAllRefreshTokens(user.id);
    }
    if (updatedEmail && await isBootstrapAdmin(user)) {
      final boundEmail = newEmail?.trim().toLowerCase();
      if (boundEmail != null && boundEmail.isNotEmpty) {
        await _settings.closeBootstrapLogin(boundEmail: boundEmail);
      }
    }

    return AccountUpdateAttempt.success(
      updatedEmail: updatedEmail,
      updatedPassword: updatedPassword,
      updatedNickname: updatedNickname,
    );
  }

  Future<EmailActionAttempt> sendBindEmailCode({
    required String userId,
    required String newEmail,
    required String currentPassword,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    if (currentPassword.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'current_password is required.',
      );
    }

    final valid = await _passwordHasher.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      return const EmailActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }

    final targetEmail = newEmail.trim().toLowerCase();
    if (targetEmail.isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'email is required.',
      );
    }
    if (user.roles.contains('admin') &&
        _isReservedBootstrapEmail(targetEmail)) {
      return const EmailActionAttempt.failure(
        code: 'invalid_email',
        message: '管理员邮箱不能使用保留的本地域名。',
      );
    }
    final existing = await _users.findByEmail(targetEmail);
    if (existing != null && existing.id != user.id) {
      return const EmailActionAttempt.failure(
        code: 'email_exists',
        message: '邮箱已被占用。',
        statusCode: 409,
      );
    }

    final limited = await _enforceVerificationCodeSendGuards(
      email: targetEmail,
      requestIp: requestIp,
      policy: policy,
      emailScope: _verificationCodeBindEmailScope,
      ipScope: _verificationCodeBindIpScope,
      cooldownScope: _verificationCodeBindCooldownScope,
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

    await _emailCodeService.issueBindEmailCode(targetEmail);
    await _startVerificationCodeCooldown(
      email: targetEmail,
      seconds: policy.bindEmailCodeCooldownSeconds,
      cooldownScope: _verificationCodeBindCooldownScope,
    );
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> bindEmailWithCode({
    required String userId,
    required String newEmail,
    required String currentPassword,
    required String emailCode,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    if (currentPassword.trim().isEmpty || emailCode.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'current_password and email_code are required.',
      );
    }

    final valid = await _passwordHasher.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      return const EmailActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }

    final targetEmail = newEmail.trim().toLowerCase();
    if (user.roles.contains('admin') &&
        _isReservedBootstrapEmail(targetEmail)) {
      return const EmailActionAttempt.failure(
        code: 'invalid_email',
        message: '管理员邮箱不能使用保留的本地域名。',
      );
    }
    final existing = await _users.findByEmail(targetEmail);
    if (existing != null && existing.id != user.id) {
      return const EmailActionAttempt.failure(
        code: 'email_exists',
        message: '邮箱已被占用。',
        statusCode: 409,
      );
    }

    final codeValid = await _emailCodeService.verifyBindEmailCode(
      targetEmail,
      emailCode.trim(),
    );
    if (!codeValid) {
      return const EmailActionAttempt.failure(
        code: 'invalid_code',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }

    await _users.updateEmail(userId: user.id, email: targetEmail);
    await _revokeAllRefreshTokens(user.id);
    if (await isBootstrapAdmin(user)) {
      await _settings.closeBootstrapLogin(boundEmail: targetEmail);
    }
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> sendPasswordResetCode({
    required String userId,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }

    final limited = await _enforceVerificationCodeSendGuards(
      email: user.email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _verificationCodeResetEmailScope,
      ipScope: _verificationCodeResetIpScope,
      cooldownScope: _verificationCodeResetCooldownScope,
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

    await _emailCodeService.issuePasswordResetCode(user.email);
    await _startVerificationCodeCooldown(
      email: user.email,
      seconds: policy.passwordResetCodeCooldownSeconds,
      cooldownScope: _verificationCodeResetCooldownScope,
    );
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> resetPasswordWithCode({
    required String userId,
    required String newPassword,
    required String emailCode,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    if (newPassword.trim().isEmpty || emailCode.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'new_password and email_code are required.',
      );
    }

    final codeValid = await _emailCodeService.verifyPasswordResetCode(
      user.email,
      emailCode.trim(),
    );
    if (!codeValid) {
      return const EmailActionAttempt.failure(
        code: 'invalid_code',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }

    final passwordHash = await _passwordHasher.hash(newPassword.trim());
    await _users.updatePasswordHash(
      userId: user.id,
      passwordHash: passwordHash,
    );
    await _revokeAllRefreshTokens(user.id);
    return const EmailActionAttempt.success();
  }

  Future<CredentialActionAttempt> updateSecurityCode({
    required String userId,
    required String currentPassword,
    required String securityCode,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const CredentialActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    if (currentPassword.trim().isEmpty || securityCode.trim().isEmpty) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_request',
        message: 'current_password and security_code are required.',
      );
    }

    final normalizedCode = securityCode.trim();
    final isDigitsOnly = RegExp(r'^\d{6,12}$').hasMatch(normalizedCode);
    if (!isDigitsOnly) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_security_code',
        message: '安全码需为 6 到 12 位数字。',
      );
    }

    final valid = await _passwordHasher.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }

    final securityCodeHash = await _passwordHasher.hash(normalizedCode);
    await _users.updateSecurityCodeHash(
      userId: user.id,
      securityCodeHash: securityCodeHash,
    );
    await _audit.log(
      action: 'user.security_code.updated',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'has_security_code': true},
    );
    return const CredentialActionAttempt.success();
  }

  Future<Map<String, String>?> beginAuthenticatorSetup({
    required String userId,
    required String currentPassword,
  }) async {
    final user = await _users.findById(userId);
    if (user == null || _authenticator == null) {
      return null;
    }
    final valid = await _passwordHasher.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      return null;
    }
    final secret = _authenticator.generateSecret();
    return {
      'secret': secret,
      'otpauth_uri': _authenticator.buildOtpAuthUri(
        email: user.email,
        secret: secret,
      ),
    };
  }

  Future<CredentialActionAttempt> verifyAuthenticatorSetup({
    required String userId,
    required String currentPassword,
    required String secret,
    required String code,
  }) async {
    final user = await _users.findById(userId);
    if (user == null || _authenticator == null) {
      return const CredentialActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    final valid = await _passwordHasher.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }
    final verified = _authenticator.verifyCode(
      secret: secret.trim(),
      code: code.trim(),
    );
    if (!verified) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_totp_code',
        message: 'Authenticator 动态验证码已过期或不正确，请确认设备时间后重试。',
        statusCode: 401,
      );
    }
    await _users.updateAuthenticatorSecret(
      userId: user.id,
      authenticatorSecret: secret.trim(),
    );
    await _audit.log(
      action: 'user.authenticator.updated',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'has_authenticator': true},
    );
    return const CredentialActionAttempt.success();
  }

  Future<Map<String, dynamic>?> beginWebAuthnRegistration({
    required String userId,
    required String origin,
    String? currentPassword,
    bool allowPostRegistrationBootstrap = false,
  }) async {
    final user = await _users.findById(userId);
    if (user == null || _webAuthn == null) {
      return null;
    }
    // Adding a passkey is normally a step-up action, so the standard path
    // still requires the current password. We only skip that check during the
    // very short window immediately after a successful self-registration, and
    // only when the current access token explicitly carries that bootstrap
    // claim. This keeps the onboarding smooth without creating a standing
    // privilege for arbitrary logged-in sessions.
    if (!allowPostRegistrationBootstrap) {
      final valid = await _passwordHasher.verify(
        user.passwordHash,
        currentPassword ?? '',
      );
      if (!valid) {
        return null;
      }
    }
    final credentialCount = await _webAuthn.countCredentials(user.id);
    if (credentialCount >= _maxWebAuthnCredentials) {
      throw const _CredentialLimitException();
    }
    return _webAuthn.generateRegistrationOptions(
      userId: user.id,
      email: user.email,
      nickname: user.nickname,
      origin: origin,
    );
  }

  Future<bool> verifyWebAuthnRegistration({
    required String userId,
    required Map<String, dynamic> response,
  }) async {
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      return false;
    }
    return webAuthn.verifyRegistration(userId: userId, response: response);
  }

  Future<List<Map<String, dynamic>>> listWebAuthnCredentials({
    required String userId,
  }) async {
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      return const [];
    }
    return webAuthn.listCredentials(userId);
  }

  Future<void> deleteWebAuthnCredential({
    required String userId,
    required String credentialId,
  }) async {
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      return;
    }
    await webAuthn.deleteCredential(userId: userId, credentialId: credentialId);
    await _audit.log(
      action: 'user.webauthn.deleted',
      actorId: userId,
      actorType: 'user',
      resourceType: 'user_webauthn_credential',
      resourceId: credentialId,
      metadata: {'deleted': true},
    );
  }

  Future<Map<String, dynamic>?> beginWebAuthnAuthentication({
    String? email,
    required String origin,
  }) async {
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      return null;
    }
    if (email == null || email.trim().isEmpty) {
      return webAuthn.generateAuthenticationOptions(origin: origin);
    }
    final user = await _users.findByEmail(email);
    if (user == null) {
      return null;
    }
    return webAuthn.generateAuthenticationOptions(
      email: user.email,
      origin: origin,
      userId: user.id,
    );
  }

  Future<LoginAttempt> loginWithWebAuthn({
    String? email,
    required Map<String, dynamic> response,
    String? requestIp,
  }) async {
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '通行密钥登录失败。',
        statusCode: 401,
      );
    }

    UserRecord? user;
    if (email != null && email.trim().isNotEmpty) {
      user = await _users.findByEmail(email);
      if (user == null) {
        return const LoginAttempt.failure(
          code: 'login_failed',
          message: '通行密钥登录失败。',
          statusCode: 401,
        );
      }
    } else {
      final credentialId = ((response['id'] ?? response['rawId']) ?? '')
          .toString();
      if (credentialId.isEmpty) {
        return const LoginAttempt.failure(
          code: 'login_failed',
          message: '通行密钥登录失败。',
          statusCode: 401,
        );
      }
      final credential = await webAuthn.findCredential(credentialId);
      if (credential == null) {
        return const LoginAttempt.failure(
          code: 'login_failed',
          message: '通行密钥登录失败。',
          statusCode: 401,
        );
      }
      user = await _users.findById(credential.userId);
      if (user == null) {
        return const LoginAttempt.failure(
          code: 'login_failed',
          message: '通行密钥登录失败。',
          statusCode: 401,
        );
      }
    }

    final verified = await webAuthn.verifyAuthentication(
      userId: email == null || email.trim().isEmpty ? null : user.id,
      email: email == null || email.trim().isEmpty ? null : user.email,
      response: response,
    );
    if (!verified) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '通行密钥登录失败。',
        statusCode: 401,
      );
    }

    final authResult = await _issueFirstPartyAuthResult(user);
    await _audit.log(
      action: 'user.login.webauthn',
      actorId: user.id,
      actorType: 'user',
      resourceType: 'user',
      resourceId: user.id,
      metadata: {'email': user.email, 'webauthn': true},
      ip: requestIp,
    );
    return LoginAttempt.success(authResult);
  }

  Future<Map<String, bool>> getSecurityState({required String userId}) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const {'has_passkey': false, 'has_authenticator': false};
    }
    final hasPasskey = _webAuthn == null
        ? false
        : await _webAuthn.hasCredentials(userId);
    return {
      'has_passkey': hasPasskey,
      'has_authenticator': user.hasAuthenticator,
    };
  }

  Future<TokenPair?> refresh(String refreshToken) async {
    return refreshForClient(refreshToken, clientId: 'first_party_web');
  }

  Future<TokenPair?> refreshForClient(
    String refreshToken, {
    required String clientId,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final security = _security;
    if (security != null &&
        policy.ipRateLimitEnabled &&
        requestIp != null &&
        requestIp.trim().isNotEmpty) {
      final ipDecision = await security.enforce(
        scope: 'refresh:$clientId:ip',
        subject: _subjectOrEmpty(requestIp),
        limit: policy.refreshIpLimit,
        window: Duration(seconds: policy.refreshWindowSeconds),
        blockDuration: Duration(seconds: policy.refreshBlockSeconds),
      );
      if (!ipDecision.allowed) {
        return null;
      }
    }

    final verified = await _tokenValidation.verifyActiveRefreshToken(
      refreshToken,
    );
    if (verified == null) {
      return null;
    }

    final payload = verified.payload;
    final tokenId = payload['jti'] as String?;
    final userId = payload['sub'] as String?;
    final tokenClientId =
        (payload['client_id'] as String?)?.trim().isNotEmpty == true
        ? payload['client_id'] as String
        : 'first_party_web';
    if (tokenId == null || userId == null) {
      return null;
    }
    if (tokenClientId != clientId) {
      return null;
    }

    final refreshRecord = await _oidcRepository.findRefreshToken(tokenId);
    if (refreshRecord == null ||
        (refreshRecord['client_id'] as String?) != clientId) {
      return null;
    }

    final user = await _users.findById(userId);
    if (user == null) {
      return null;
    }

    await _oidcRepository.revokeRefreshToken(tokenId);

    final pair = _tokenService.issueTokenPair(
      user.toAuthenticatedUser(),
      clientId: clientId,
    );
    await _oidcRepository.storeAccessToken(
      tokenId: pair.accessTokenId,
      userId: user.id,
      clientId: clientId,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: _tokenService.accessTokenTtlSeconds),
      ),
    );
    await _oidcRepository.storeRefreshToken(
      tokenId: pair.refreshTokenId,
      userId: user.id,
      clientId: clientId,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: _tokenService.refreshTokenTtlSeconds),
      ),
    );

    return pair;
  }

  Future<LoginAttempt?> _enforceLoginGuards({
    required String email,
    String? requestIp,
    required int emailLimit,
    required int ipLimit,
    required Duration window,
    required Duration blockDuration,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    if (policy.emailRateLimitEnabled) {
      final emailDecision = await security.enforce(
        scope: 'login:email',
        subject: normalizedEmail,
        limit: emailLimit,
        window: window,
        blockDuration: blockDuration,
      );
      if (!emailDecision.allowed) {
        return LoginAttempt.failure(
          code: 'rate_limited',
          message: '尝试次数过多，请稍后再试。',
          statusCode: 429,
        );
      }
    }

    final ipSubject = _subjectOrEmpty(requestIp);
    if (ipSubject.isEmpty || !policy.ipRateLimitEnabled) {
      return null;
    }

    final ipDecision = await security.enforce(
      scope: 'login:ip',
      subject: ipSubject,
      limit: ipLimit,
      window: window,
      blockDuration: blockDuration,
    );
    if (!ipDecision.allowed) {
      return LoginAttempt.failure(
        code: 'rate_limited',
        message: '尝试次数过多，请稍后再试。',
        statusCode: 429,
      );
    }
    return null;
  }

  Future<void> _clearLoginGuards({required String email}) {
    final security = _security;
    if (security == null) {
      return Future.value();
    }
    return security.clear(
      scope: 'login:email',
      subject: email.trim().toLowerCase(),
    );
  }

  Future<AdminLoginCodeAttempt?> _enforceRequestGuards({
    required String emailScope,
    required String ipScope,
    required String email,
    String? requestIp,
    required int emailLimit,
    required int ipLimit,
    required Duration window,
    required Duration blockDuration,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    if (policy.emailRateLimitEnabled) {
      final emailDecision = await security.enforce(
        scope: emailScope,
        subject: normalizedEmail,
        limit: emailLimit,
        window: window,
        blockDuration: blockDuration,
      );
      if (!emailDecision.allowed) {
        return const AdminLoginCodeAttempt.failure(
          code: 'rate_limited',
          message: '请求过于频繁，请稍后再试。',
          statusCode: 429,
        );
      }
    }

    final ipSubject = _subjectOrEmpty(requestIp);
    if (ipSubject.isEmpty || !policy.ipRateLimitEnabled) {
      return null;
    }

    final ipDecision = await security.enforce(
      scope: ipScope,
      subject: ipSubject,
      limit: ipLimit,
      window: window,
      blockDuration: blockDuration,
    );
    if (!ipDecision.allowed) {
      return const AdminLoginCodeAttempt.failure(
        code: 'rate_limited',
        message: '请求过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }

    return null;
  }

  Future<AdminLoginCodeAttempt?> _enforceVerificationCodeSendGuards({
    required String email,
    String? requestIp,
    required SecurityPolicy policy,
    required String emailScope,
    required String ipScope,
    required String cooldownScope,
    required int emailLimit,
    required int ipLimit,
  }) async {
    final cooldownRetry = await verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: cooldownScope,
    );
    if (cooldownRetry != null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'rate_limited',
        message: '请求过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }

    return _enforceRequestGuards(
      emailScope: emailScope,
      ipScope: ipScope,
      email: email,
      requestIp: requestIp,
      emailLimit: emailLimit,
      ipLimit: ipLimit,
      window: Duration(seconds: policy.adminLoginCodeWindowSeconds),
      blockDuration: Duration(seconds: policy.adminLoginCodeBlockSeconds),
    );
  }

  int? _maxRetryAfter(int? left, int? right) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left > right ? left : right;
  }

  String _subjectOrEmpty(String? raw) => raw?.trim() ?? '';

  Future<void> _startVerificationCodeCooldown({
    required String email,
    required int seconds,
    required String cooldownScope,
  }) async {
    final security = _security;
    if (security == null) {
      return;
    }
    await security.startCooldown(
      scope: cooldownScope,
      subject: email.trim().toLowerCase(),
      duration: Duration(seconds: seconds),
    );
  }

  Future<AuthResult> _issueFirstPartyAuthResult(
    UserRecord user, {
    bool postRegistrationPasskeyBootstrap = false,
  }) async {
    // This short-lived claim is intentionally only minted on the access token
    // returned by self-registration. Later logins and refreshed sessions do
    // not receive it, so the no-password onboarding flow cannot become a
    // general-purpose bypass for adding new passkeys.
    final bootstrapUntilEpochSeconds =
        postRegistrationPasskeyBootstrap
        ? DateTime.now()
              .toUtc()
              .add(
                const Duration(
                  seconds: _postRegistrationPasskeyBootstrapSeconds,
                ),
              )
              .millisecondsSinceEpoch ~/
            1000
        : null;
    final tokens = _tokenService.issueTokenPair(
      user.toAuthenticatedUser(),
      additionalAccessClaims: {
        if (bootstrapUntilEpochSeconds != null)
          'post_register_passkey_bootstrap_until':
              bootstrapUntilEpochSeconds,
      },
    );
    await _oidcRepository.storeAccessToken(
      tokenId: tokens.accessTokenId,
      userId: user.id,
      clientId: 'first_party_web',
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: _tokenService.accessTokenTtlSeconds),
      ),
    );
    return AuthResult(
      user: user.toAuthenticatedUser(),
      tokens: tokens,
      postRegistrationPasskeyBootstrap: postRegistrationPasskeyBootstrap,
    );
  }

  Future<void> logoutFirstPartySession({String? accessToken}) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      return;
    }
    final verified = await _tokenValidation.verifyActiveAccessToken(token);
    final tokenId = verified?.payload['jti'] as String?;
    if (tokenId == null) {
      return;
    }
    await _oidcRepository.revokeAccessToken(tokenId);
  }

  bool mustBindAdminEmail(UserRecord user) {
    return user.roles.contains('admin') &&
        _isReservedBootstrapEmail(user.email);
  }

  Future<bool> isBootstrapAdmin(UserRecord user) async {
    if (!mustBindAdminEmail(user)) {
      return false;
    }
    return _settings.isBootstrapLoginEnabled();
  }

  bool _isReservedBootstrapEmail(String email) {
    return email.toLowerCase().trim().endsWith('@rosm.local');
  }

  Future<void> _revokeAllRefreshTokens(String userId) {
    return Future.wait([
      _oidcRepository.revokeRefreshTokensForUser(userId),
      _oidcRepository.revokeAccessTokensForUser(userId),
    ]);
  }
}
