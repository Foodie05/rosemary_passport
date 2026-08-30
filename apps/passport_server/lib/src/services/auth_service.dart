export 'auth_attempts.dart';

import '../repositories/oidc_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/password_policy.dart';
import '../security/token_service.dart';
import 'audit_service.dart';
import 'account_recovery_service.dart';
import 'account_management_service.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'authenticator_service.dart';
import 'captcha_service.dart';
import 'credential_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'registration_service.dart';
import 'security_policy_service.dart';
import 'security_service.dart';
import 'session_service.dart';
import 'webauthn_service.dart';

class AuthService {
  AuthService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required PasswordPolicy passwordPolicy,
    required TokenService tokenService,
    required EmailCodeService emailCodeService,
    required CaptchaService captchaService,
    required OidcRepository oidcRepository,
    required SettingsRepository settingsRepository,
    required AuditService auditService,
    SecurityService? securityService,
    SecurityPolicyService? securityPolicyService,
    AuthenticatorService? authenticatorService,
    WebAuthnService? webAuthnService,
    PhoneVerificationService? phoneVerificationService,
  }) : _users = userRepository,
       _passwordHasher = passwordHasher,
       _emailCodeService = emailCodeService,
       _captchaService = captchaService,
       _settings = settingsRepository,
       _audit = auditService,
       _authenticator = authenticatorService,
       _webAuthn = webAuthnService,
       _phoneVerification = phoneVerificationService,
       _sessions = SessionService(
         userRepository: userRepository,
         tokenService: tokenService,
         oidcRepository: oidcRepository,
         auditService: auditService,
         securityService: securityService,
         securityPolicyService: securityPolicyService,
       ),
       _credentials = CredentialService(
         userRepository: userRepository,
         passwordHasher: passwordHasher,
         auditService: auditService,
         authenticatorService: authenticatorService,
         webAuthnService: webAuthnService,
       ),
       _throttles = AuthThrottleService(
         securityService: securityService,
         securityPolicyService: securityPolicyService,
       ),
       _accountRecovery = AccountRecoveryService(
         userRepository: userRepository,
         passwordHasher: passwordHasher,
         passwordPolicy: passwordPolicy,
         emailCodeService: emailCodeService,
         throttleService: AuthThrottleService(
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         sessionService: SessionService(
           userRepository: userRepository,
           tokenService: tokenService,
           oidcRepository: oidcRepository,
           auditService: auditService,
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         phoneVerificationService: phoneVerificationService,
       ),
       _accountManagement = AccountManagementService(
         userRepository: userRepository,
         settingsRepository: settingsRepository,
         passwordHasher: passwordHasher,
         passwordPolicy: passwordPolicy,
         emailCodeService: emailCodeService,
         throttleService: AuthThrottleService(
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         sessionService: SessionService(
           userRepository: userRepository,
           tokenService: tokenService,
           oidcRepository: oidcRepository,
           auditService: auditService,
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         phoneVerificationService: phoneVerificationService,
       ),
       _registration = RegistrationService(
         userRepository: userRepository,
         passwordHasher: passwordHasher,
         passwordPolicy: passwordPolicy,
         emailCodeService: emailCodeService,
         throttleService: AuthThrottleService(
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         sessionService: SessionService(
           userRepository: userRepository,
           tokenService: tokenService,
           oidcRepository: oidcRepository,
           auditService: auditService,
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         auditService: auditService,
         securityPolicyService: securityPolicyService,
         phoneVerificationService: phoneVerificationService,
       );

  final UserRepository _users;
  final PasswordHasher _passwordHasher;
  final EmailCodeService _emailCodeService;
  final CaptchaService _captchaService;
  final SettingsRepository _settings;
  final AuditService _audit;
  final AuthenticatorService? _authenticator;
  final WebAuthnService? _webAuthn;
  final PhoneVerificationService? _phoneVerification;
  final SessionService _sessions;
  final CredentialService _credentials;
  final AuthThrottleService _throttles;
  final AccountRecoveryService _accountRecovery;
  final AccountManagementService _accountManagement;
  final RegistrationService _registration;
  static const _verificationCodeRegisterEmailScope =
      'verification-code:register:email';
  static const _verificationCodeRegisterIpScope =
      'verification-code:register:ip';
  static const _verificationCodeRegisterCooldownScope =
      'verification-code:register:cooldown:email';
  static const _verificationCodeLoginEmailScope =
      'verification-code:login:email';
  static const _verificationCodeLoginIpScope = 'verification-code:login:ip';
  static const _verificationCodeLoginCooldownScope =
      'verification-code:login:cooldown:email';
  static const _verificationCodeMfaEmailScope =
      'verification-code:mfa-login:email';
  static const _verificationCodeMfaIpScope = 'verification-code:mfa-login:ip';
  static const _verificationCodeMfaCooldownScope =
      'verification-code:mfa-login:cooldown:email';
  static const _verificationCodeBindEmailScope =
      'verification-code:bind-email:email';
  static const _verificationCodeBindIpScope = 'verification-code:bind-email:ip';
  static const _verificationCodeBindCooldownScope =
      'verification-code:bind-email:cooldown:email';
  static const _verificationCodeResetEmailScope =
      'verification-code:password-reset:email';
  static const _verificationCodeResetIpScope =
      'verification-code:password-reset:ip';
  static const _verificationCodeResetCooldownScope =
      'verification-code:password-reset:cooldown:email';
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
    return _registration.sendEmailCode(email: email, requestIp: requestIp);
  }

  Future<int?> loginRetryAfter({required String email, String? requestIp}) {
    return _throttles.loginRetryAfter(email: email, requestIp: requestIp);
  }

  Future<int?> adminCodeRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = await _throttles.loadPolicy();
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
  }) {
    return _throttles.verificationCodeRetryAfter(
      email: email,
      requestIp: requestIp,
      emailScope: emailScope,
      ipScope: ipScope,
      cooldownScope: cooldownScope,
      emailLimit: emailLimit,
      ipLimit: ipLimit,
    );
  }

  Future<int?> verificationCodeCooldownRetryAfter({
    required String email,
    required String cooldownScope,
  }) {
    return _throttles.verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: cooldownScope,
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

  Future<int?> registerCodeCooldownRetryAfter({required String email}) {
    return verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: _verificationCodeRegisterCooldownScope,
    );
  }

  Future<int?> loginCodeSendRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final policy = await _throttles.loadPolicy();
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
    final policy = await _throttles.loadPolicy();
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
    final policy = await _throttles.loadPolicy();
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
    final policy = await _throttles.loadPolicy();
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
    final policy = await _throttles.loadPolicy();
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
    return _throttles.refreshRetryAfter(requestIp: requestIp);
  }

  Future<AdminLoginCodeAttempt> sendLoginCode({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    final policy = await _throttles.loadPolicy();
    final loginCodeLimited = await _throttles.enforceVerificationCodeSendGuards(
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
    await _throttles.startVerificationCodeCooldown(
      email: user.email,
      seconds: policy.adminLoginCodeCooldownSeconds,
      cooldownScope: _verificationCodeMfaCooldownScope,
    );
    return const AdminLoginCodeAttempt.success();
  }

  Future<AdminLoginCodeAttempt> sendPasswordPhoneLoginCode({
    required String email,
    required String password,
    String? requestIp,
  }) async {
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

    final phoneService = _phoneVerification;
    final phone = user.phoneNumber?.trim() ?? '';
    if (phoneService == null || phone.isEmpty || !user.isPhoneVerified) {
      return const AdminLoginCodeAttempt.failure(
        code: 'mfa_not_available',
        message: '当前账户未配置手机号验证。',
        statusCode: 400,
      );
    }

    final sent = await phoneService.sendCode(
      phoneNumber: phone,
      requestIp: _subjectOrEmpty(requestIp),
    );
    if (!sent.ok) {
      return AdminLoginCodeAttempt.failure(
        code: sent.code ?? 'temporary_issue',
        message: sent.message ?? '验证码发送失败，请稍后重试。',
        statusCode: sent.statusCode,
      );
    }
    return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
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
    if ((user.phoneNumber ?? '').trim().isNotEmpty && user.isPhoneVerified) {
      factors.insert(0, 'phone_code');
    }
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
    final policy = await _throttles.loadPolicy();
    final loginCodeLimited = await _throttles.enforceVerificationCodeSendGuards(
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
    if (user == null || user.roles.contains('admin')) {
      await _throttles.startVerificationCodeCooldown(
        email: email,
        seconds: policy.loginCodeCooldownSeconds,
        cooldownScope: _verificationCodeLoginCooldownScope,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return const AdminLoginCodeAttempt.success(
        message: '如果账号存在，验证码将发送到已绑定邮箱。',
      );
    }
    await _emailCodeService.issueLoginCode(
      user.email,
      templateName: 'login_verification',
    );
    await _throttles.startVerificationCodeCooldown(
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
    return _registration.registerWithEmail(
      email: email,
      nickname: nickname,
      password: password,
      emailCode: emailCode,
      requestIp: requestIp,
    );
  }

  Future<AdminLoginCodeAttempt> sendPhoneRegisterCode({
    required String phoneNumber,
    String? requestIp,
  }) async {
    return _registration.sendPhoneCode(
      phoneNumber: phoneNumber,
      requestIp: requestIp,
    );
  }

  Future<RegisterAttempt> registerWithPhoneCode({
    required String phoneNumber,
    required String nickname,
    required String password,
    required String verifyCode,
    String? requestIp,
  }) async {
    return _registration.registerWithPhone(
      phoneNumber: phoneNumber,
      nickname: nickname,
      password: password,
      verifyCode: verifyCode,
      requestIp: requestIp,
    );
  }

  Future<EmailActionAttempt> sendAccountRecoveryCode({
    required String account,
    required String method,
    String? requestIp,
  }) async {
    return _accountRecovery.sendCode(
      account: account,
      method: method,
      requestIp: requestIp,
    );
  }

  Future<EmailActionAttempt> recoverPasswordWithCode({
    required String account,
    required String method,
    required String code,
    required String newPassword,
    String? requestIp,
  }) async {
    return _accountRecovery.recoverPassword(
      account: account,
      method: method,
      code: code,
      newPassword: newPassword,
      requestIp: requestIp,
    );
  }

  Future<LoginAttempt> login({
    required String email,
    required String password,
    String? factorType,
    String? emailCode,
    String? phoneCode,
    String? authenticatorCode,
    String? requestIp,
    bool rememberMe = false,
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
      final authResult = await _issueFirstPartyAuthResult(
        user,
        rememberMe: rememberMe,
      );
      await _throttles.clearLoginGuards(email: email);
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
      final authResult = await _issueFirstPartyAuthResult(
        user,
        rememberMe: rememberMe,
      );
      final consumed = await _emailCodeService.consumeCode(codeId);
      if (!consumed) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '邮箱验证码无效或已过期。',
          statusCode: 401,
        );
      }
      await _throttles.clearLoginGuards(email: email);

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
    } else if (normalizedFactor == 'phone_code') {
      if (phoneCode == null || phoneCode.trim().isEmpty) {
        return const LoginAttempt.failure(
          code: 'mfa_required',
          message: '登录需要手机验证码。',
          statusCode: 401,
        );
      }
      final phoneService = _phoneVerification;
      final phone = user.phoneNumber?.trim() ?? '';
      if (phoneService == null || phone.isEmpty || !user.isPhoneVerified) {
        return const LoginAttempt.failure(
          code: 'mfa_not_available',
          message: '当前账户未配置手机号验证。',
          statusCode: 400,
        );
      }
      final checked = await phoneService.verifyCode(
        phoneNumber: phone,
        verifyCode: phoneCode.trim(),
        requestIp: _subjectOrEmpty(requestIp),
      );
      if (!checked.ok) {
        return LoginAttempt.failure(
          code: checked.code ?? 'mfa_required',
          message: checked.message ?? '手机验证码无效或已过期。',
          statusCode: checked.statusCode,
        );
      }
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

    final authResult = await _issueFirstPartyAuthResult(
      user,
      rememberMe: rememberMe,
    );
    await _throttles.clearLoginGuards(email: email);

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
    bool rememberMe = false,
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

    final authResult = await _issueFirstPartyAuthResult(
      user,
      rememberMe: rememberMe,
    );
    final consumed = await _emailCodeService.consumeCode(codeId);
    if (!consumed) {
      return const LoginAttempt.failure(
        code: 'mfa_required',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }
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

    return LoginAttempt.success(authResult);
  }

  Future<AdminLoginCodeAttempt> sendPhoneLoginCode({
    required String phoneNumber,
    String? requestIp,
  }) async {
    final phoneService = _phoneVerification;
    if (phoneService == null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }
    final normalized = phoneService.normalizePhone(phoneNumber);
    if (normalized == null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }
    final user = await _users.findByPhoneNumber(normalized);
    if (user == null) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return const AdminLoginCodeAttempt.success(
        message: '如果账号存在，验证码将发送到已绑定手机号。',
      );
    }
    final attempt = await phoneService.sendCode(
      phoneNumber: normalized,
      requestIp: _subjectOrEmpty(requestIp),
    );
    if (!attempt.ok) {
      return AdminLoginCodeAttempt.failure(
        code: attempt.code ?? 'temporary_issue',
        message: attempt.message ?? '验证码发送失败，请稍后重试。',
        statusCode: attempt.statusCode,
      );
    }
    return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
  }

  Future<LoginAttempt> loginWithPhoneCode({
    required String phoneNumber,
    required String verifyCode,
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final phoneService = _phoneVerification;
    if (phoneService == null) {
      return const LoginAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }
    final normalized = phoneService.normalizePhone(phoneNumber);
    if (normalized == null) {
      return const LoginAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }
    final user = await _users.findByPhoneNumber(normalized);
    if (user == null) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '登录失败。',
        statusCode: 401,
      );
    }
    final checked = await phoneService.verifyCode(
      phoneNumber: normalized,
      verifyCode: verifyCode,
      requestIp: _subjectOrEmpty(requestIp),
    );
    if (!checked.ok) {
      return LoginAttempt.failure(
        code: checked.code ?? 'mfa_required',
        message: checked.message ?? '手机验证码无效或已过期。',
        statusCode: checked.statusCode,
      );
    }
    final authResult = await _issueFirstPartyAuthResult(
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
    return LoginAttempt.success(authResult);
  }

  Future<AccountUpdateAttempt> updateSelfAccount({
    required String userId,
    required String currentPassword,
    String? nickname,
    String? newEmail,
    String? newPassword,
  }) async {
    return _accountManagement.updateAccount(
      userId: userId,
      currentPassword: currentPassword,
      nickname: nickname,
      newEmail: newEmail,
      newPassword: newPassword,
    );
  }

  Future<EmailActionAttempt> sendBindEmailCode({
    required String userId,
    required String newEmail,
    required String currentPassword,
    String? requestIp,
  }) async {
    return _accountManagement.sendBindEmailCode(
      userId: userId,
      newEmail: newEmail,
      currentPassword: currentPassword,
      requestIp: requestIp,
    );
  }

  Future<EmailActionAttempt> bindEmailWithCode({
    required String userId,
    required String newEmail,
    required String currentPassword,
    required String emailCode,
    String? preservedAccessTokenId,
  }) async {
    return _accountManagement.bindEmail(
      userId: userId,
      newEmail: newEmail,
      currentPassword: currentPassword,
      emailCode: emailCode,
      preservedAccessTokenId: preservedAccessTokenId,
    );
  }

  Future<EmailActionAttempt> sendBindPhoneCode({
    required String userId,
    required String phoneNumber,
    required String currentPassword,
    String? requestIp,
  }) async {
    return _accountManagement.sendBindPhoneCode(
      userId: userId,
      phoneNumber: phoneNumber,
      currentPassword: currentPassword,
      requestIp: requestIp,
    );
  }

  Future<EmailActionAttempt> bindPhoneWithCode({
    required String userId,
    required String phoneNumber,
    required String currentPassword,
    required String verifyCode,
    String? requestIp,
    String? preservedAccessTokenId,
  }) async {
    return _accountManagement.bindPhone(
      userId: userId,
      phoneNumber: phoneNumber,
      currentPassword: currentPassword,
      verifyCode: verifyCode,
      requestIp: requestIp,
      preservedAccessTokenId: preservedAccessTokenId,
    );
  }

  Future<EmailActionAttempt> sendPasswordResetCode({
    required String userId,
    String? requestIp,
  }) async {
    return _accountManagement.sendPasswordResetCode(
      userId: userId,
      requestIp: requestIp,
    );
  }

  Future<EmailActionAttempt> resetPasswordWithCode({
    required String userId,
    required String newPassword,
    required String emailCode,
  }) async {
    return _accountManagement.resetPassword(
      userId: userId,
      newPassword: newPassword,
      emailCode: emailCode,
    );
  }

  Future<CredentialActionAttempt> updateSecurityCode({
    required String userId,
    required String currentPassword,
    required String securityCode,
  }) async {
    return _credentials.updateSecurityCode(
      userId: userId,
      currentPassword: currentPassword,
      securityCode: securityCode,
    );
  }

  Future<Map<String, String>?> beginAuthenticatorSetup({
    required String userId,
    required String currentPassword,
  }) async {
    return _credentials.beginAuthenticatorSetup(
      userId: userId,
      currentPassword: currentPassword,
    );
  }

  Future<CredentialActionAttempt> verifyAuthenticatorSetup({
    required String userId,
    required String currentPassword,
    required String secret,
    required String code,
  }) async {
    return _credentials.verifyAuthenticatorSetup(
      userId: userId,
      currentPassword: currentPassword,
      secret: secret,
      code: code,
    );
  }

  Future<Map<String, dynamic>?> beginWebAuthnRegistration({
    required String userId,
    required String origin,
    String? currentPassword,
    bool allowPostRegistrationBootstrap = false,
  }) async {
    return _credentials.beginWebAuthnRegistration(
      userId: userId,
      origin: origin,
      currentPassword: currentPassword,
      allowPostRegistrationBootstrap: allowPostRegistrationBootstrap,
    );
  }

  Future<bool> verifyWebAuthnRegistration({
    required String userId,
    required Map<String, dynamic> response,
  }) async {
    return _credentials.verifyWebAuthnRegistration(
      userId: userId,
      response: response,
    );
  }

  Future<List<Map<String, dynamic>>> listWebAuthnCredentials({
    required String userId,
  }) async {
    return _credentials.listWebAuthnCredentials(userId: userId);
  }

  Future<void> deleteWebAuthnCredential({
    required String userId,
    required String credentialId,
  }) async {
    return _credentials.deleteWebAuthnCredential(
      userId: userId,
      credentialId: credentialId,
    );
  }

  Future<Map<String, dynamic>?> beginWebAuthnAuthentication({
    String? email,
    required String origin,
  }) async {
    return _credentials.beginWebAuthnAuthentication(
      email: email,
      origin: origin,
    );
  }

  Future<LoginAttempt> loginWithWebAuthn({
    String? email,
    required Map<String, dynamic> response,
    String? requestIp,
    bool rememberMe = false,
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
      forceUserVerification: user.roles.contains('admin'),
    );
    if (!verified) {
      return const LoginAttempt.failure(
        code: 'login_failed',
        message: '通行密钥登录失败。',
        statusCode: 401,
      );
    }

    final authResult = await _issueFirstPartyAuthResult(
      user,
      rememberMe: rememberMe,
    );
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
    return _credentials.getSecurityState(userId: userId);
  }

  Future<TokenPair?> refresh(String refreshToken) async {
    return _sessions.refresh(refreshToken);
  }

  Future<TokenPair?> refreshForClient(
    String refreshToken, {
    required String clientId,
    String? requestIp,
  }) async {
    return _sessions.refreshForClient(
      refreshToken,
      clientId: clientId,
      requestIp: requestIp,
    );
  }

  String _subjectOrEmpty(String? raw) => raw?.trim() ?? '';

  Future<AuthResult> _issueFirstPartyAuthResult(
    UserRecord user, {
    bool postRegistrationPasskeyBootstrap = false,
    bool rememberMe = false,
  }) async {
    return _sessions.issueFirstPartyAuthResult(
      user,
      postRegistrationPasskeyBootstrap: postRegistrationPasskeyBootstrap,
      rememberMe: rememberMe,
    );
  }

  Future<void> logoutFirstPartySession({
    String? accessToken,
    String? refreshToken,
    String? requestIp,
  }) async {
    return _sessions.logoutFirstPartySession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      requestIp: requestIp,
    );
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
}
