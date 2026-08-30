import '../repositories/user_repository.dart';
import 'audit_service.dart';
import 'auth_attempts.dart';
import 'session_service.dart';
import 'webauthn_service.dart';

class PasskeyLoginService {
  PasskeyLoginService({
    required UserRepository userRepository,
    required SessionService sessionService,
    required AuditService auditService,
    WebAuthnService? webAuthnService,
  }) : _users = userRepository,
       _sessions = sessionService,
       _audit = auditService,
       _webAuthn = webAuthnService;

  final UserRepository _users;
  final SessionService _sessions;
  final AuditService _audit;
  final WebAuthnService? _webAuthn;

  Future<LoginAttempt> login({
    String? email,
    required Map<String, dynamic> response,
    String? requestIp,
    bool rememberMe = false,
  }) async {
    final webAuthn = _webAuthn;
    if (webAuthn == null) {
      return _failure;
    }

    final normalizedEmail = email?.trim() ?? '';
    UserRecord? user;
    if (normalizedEmail.isNotEmpty) {
      user = await _users.findByEmail(email!);
      if (user == null) {
        return _failure;
      }
    } else {
      final credentialId = ((response['id'] ?? response['rawId']) ?? '')
          .toString();
      if (credentialId.isEmpty) {
        return _failure;
      }
      final credential = await webAuthn.findCredential(credentialId);
      if (credential == null) {
        return _failure;
      }
      user = await _users.findById(credential.userId);
      if (user == null) {
        return _failure;
      }
    }

    final verified = await webAuthn.verifyAuthentication(
      userId: normalizedEmail.isEmpty ? null : user.id,
      email: normalizedEmail.isEmpty ? null : user.email,
      response: response,
      forceUserVerification: user.roles.contains('admin'),
    );
    if (!verified) {
      return _failure;
    }

    final auth = await _sessions.issueFirstPartyAuthResult(
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
    return LoginAttempt.success(auth);
  }

  static const _failure = LoginAttempt.failure(
    code: 'login_failed',
    message: '通行密钥登录失败。',
    statusCode: 401,
  );
}
