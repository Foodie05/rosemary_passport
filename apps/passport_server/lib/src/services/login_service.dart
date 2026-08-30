import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
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

  final UserRepository _users;
  final SettingsRepository _settings;
  final PasswordHasher _passwords;
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
    final user = await _users.findByEmail(email);
    if (user == null || user.roles.contains('admin')) {
      await _throttles.startVerificationCodeCooldown(
        email: email,
        seconds: policy.loginCodeCooldownSeconds,
        cooldownScope: _loginCooldownScope,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return const AdminLoginCodeAttempt.success(
        message: '如果账号存在，验证码将发送到已绑定邮箱。',
      );
    }
    await _emailCodes.issueLoginCode(
      user.email,
      templateName: 'login_verification',
    );
    await _throttles.startVerificationCodeCooldown(
      email: email,
      seconds: policy.loginCodeCooldownSeconds,
      cooldownScope: _loginCooldownScope,
    );
    return const AdminLoginCodeAttempt.success(message: '验证码已发送。');
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
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final limited = await _enforceLoginGuards(email, requestIp);
    if (limited != null) {
      return limited;
    }
    final user = await _users.findByEmail(email);
    if (user == null || user.roles.contains('admin')) {
      return _loginFailure;
    }
    final codeId = await _emailCodes.validateLoginCode(
      user.email,
      emailCode.trim(),
    );
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
    final user = await _users.findByPhoneNumber(normalized);
    if (user == null) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return const AdminLoginCodeAttempt.success(
        message: '如果账号存在，验证码将发送到已绑定手机号。',
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
    final user = await _users.findByPhoneNumber(normalized);
    if (user == null) {
      return _loginFailure;
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
}
