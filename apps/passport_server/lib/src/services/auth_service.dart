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
import 'login_service.dart';
import 'passkey_login_service.dart';
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
       _captchaService = captchaService,
       _settings = settingsRepository,
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
       ),
       _login = LoginService(
         userRepository: userRepository,
         settingsRepository: settingsRepository,
         passwordHasher: passwordHasher,
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
         authenticatorService: authenticatorService,
         phoneVerificationService: phoneVerificationService,
         webAuthnService: webAuthnService,
       ),
       _passkeyLogin = PasskeyLoginService(
         userRepository: userRepository,
         sessionService: SessionService(
           userRepository: userRepository,
           tokenService: tokenService,
           oidcRepository: oidcRepository,
           auditService: auditService,
           securityService: securityService,
           securityPolicyService: securityPolicyService,
         ),
         auditService: auditService,
         webAuthnService: webAuthnService,
       );

  final UserRepository _users;
  final PasswordHasher _passwordHasher;
  final CaptchaService _captchaService;
  final SettingsRepository _settings;
  final SessionService _sessions;
  final CredentialService _credentials;
  final AuthThrottleService _throttles;
  final AccountRecoveryService _accountRecovery;
  final AccountManagementService _accountManagement;
  final RegistrationService _registration;
  final LoginService _login;
  final PasskeyLoginService _passkeyLogin;
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
    return _login.sendPasswordEmailCode(
      email: email,
      password: password,
      requestIp: requestIp,
    );
  }

  Future<AdminLoginCodeAttempt> sendPasswordPhoneLoginCode({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    return _login.sendPasswordPhoneCode(
      email: email,
      password: password,
      requestIp: requestIp,
    );
  }

  Future<PasswordLoginPreparation> preparePasswordLogin({
    required String email,
    required String password,
    String? requestIp,
  }) async {
    return _login.preparePasswordLogin(
      email: email,
      password: password,
      requestIp: requestIp,
    );
  }

  Future<AdminLoginCodeAttempt> sendEmailLoginCode({
    required String email,
    String? requestIp,
  }) async {
    return _login.sendEmailCode(email: email, requestIp: requestIp);
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
  }) {
    return _login.loginWithPassword(
      email: email,
      password: password,
      factorType: factorType,
      emailCode: emailCode,
      phoneCode: phoneCode,
      authenticatorCode: authenticatorCode,
      requestIp: requestIp,
      rememberMe: rememberMe,
    );
  }

  Future<LoginAttempt> loginWithEmailCode({
    required String email,
    required String emailCode,
    String? requestIp,
    bool rememberMe = false,
  }) {
    return _login.loginWithEmailCode(
      email: email,
      emailCode: emailCode,
      requestIp: requestIp,
      rememberMe: rememberMe,
    );
  }

  Future<AdminLoginCodeAttempt> sendPhoneLoginCode({
    required String phoneNumber,
    String? requestIp,
  }) {
    return _login.sendPhoneCode(phoneNumber: phoneNumber, requestIp: requestIp);
  }

  Future<LoginAttempt> loginWithPhoneCode({
    required String phoneNumber,
    required String verifyCode,
    String? requestIp,
    bool rememberMe = false,
  }) {
    return _login.loginWithPhoneCode(
      phoneNumber: phoneNumber,
      verifyCode: verifyCode,
      requestIp: requestIp,
      rememberMe: rememberMe,
    );
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
  }) {
    return _passkeyLogin.login(
      email: email,
      response: response,
      requestIp: requestIp,
      rememberMe: rememberMe,
    );
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
