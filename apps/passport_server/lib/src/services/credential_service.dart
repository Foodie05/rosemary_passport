import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import 'audit_service.dart';
import 'auth_attempts.dart';
import 'authenticator_service.dart';
import 'webauthn_service.dart';

/// Manages user-owned security credentials without issuing login sessions.
class CredentialService {
  CredentialService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required AuditService auditService,
    AuthenticatorService? authenticatorService,
    WebAuthnService? webAuthnService,
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _audit = auditService,
       _authenticator = authenticatorService,
       _webAuthn = webAuthnService;

  static const maxWebAuthnCredentials = 5;

  final UserRepository _users;
  final PasswordHasher _passwords;
  final AuditService _audit;
  final AuthenticatorService? _authenticator;
  final WebAuthnService? _webAuthn;

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
    if (!RegExp(r'^\d{6,12}$').hasMatch(normalizedCode)) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_security_code',
        message: '安全码需为 6 到 12 位数字。',
      );
    }

    final valid = await _passwords.verify(user.passwordHash, currentPassword);
    if (!valid) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }

    final securityCodeHash = await _passwords.hash(normalizedCode);
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
    bool stepUpVerified = false,
  }) async {
    final user = await _users.findById(userId);
    final authenticator = _authenticator;
    if (user == null || authenticator == null) {
      return null;
    }
    final valid =
        stepUpVerified ||
        await _passwords.verify(user.passwordHash, currentPassword);
    if (!valid) {
      return null;
    }
    final secret = authenticator.generateSecret();
    return {
      'secret': secret,
      'otpauth_uri': authenticator.buildOtpAuthUri(
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
    bool stepUpVerified = false,
  }) async {
    final user = await _users.findById(userId);
    final authenticator = _authenticator;
    if (user == null || authenticator == null) {
      return const CredentialActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    final valid =
        stepUpVerified ||
        await _passwords.verify(user.passwordHash, currentPassword);
    if (!valid) {
      return const CredentialActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }
    final verified = authenticator.verifyCode(
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
    bool stepUpVerified = false,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return null;
    }
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      throw const WebAuthnUnavailableException();
    }
    if (!allowPostRegistrationBootstrap && !stepUpVerified) {
      final valid = await _passwords.verify(
        user.passwordHash,
        currentPassword ?? '',
      );
      if (!valid) {
        return null;
      }
    }
    final credentialCount = await webAuthn.countCredentials(user.id);
    if (credentialCount >= maxWebAuthnCredentials) {
      throw const WebAuthnCredentialLimitException();
    }
    return webAuthn.generateRegistrationOptions(
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
    return webAuthn != null &&
        await webAuthn.verifyRegistration(userId: userId, response: response);
  }

  Future<List<Map<String, dynamic>>> listWebAuthnCredentials({
    required String userId,
  }) async {
    return _webAuthn?.listCredentials(userId) ?? const [];
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
      // A discoverable credential does not reveal its account until after the
      // assertion. Require UV up front so an administrator assertion cannot be
      // generated as "preferred" and then rejected by the role-aware verifier.
      return webAuthn.generateAuthenticationOptions(
        origin: origin,
        requireUserVerification: true,
      );
    }
    final user = await _users.findByEmail(email);
    if (user == null) {
      return null;
    }
    return webAuthn.generateAuthenticationOptions(
      email: user.email,
      origin: origin,
      userId: user.id,
      requireUserVerification: user.roles.contains('admin'),
    );
  }

  Future<Map<String, bool>> getSecurityState({required String userId}) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const {
        'has_passkey': false,
        'has_authenticator': false,
        'has_phone': false,
      };
    }
    final hasPasskey = _webAuthn == null
        ? false
        : await _webAuthn.hasCredentials(userId);
    return {
      'has_passkey': hasPasskey,
      'has_authenticator': user.hasAuthenticator,
      'has_phone':
          (user.phoneNumber ?? '').trim().isNotEmpty && user.isPhoneVerified,
    };
  }
}
