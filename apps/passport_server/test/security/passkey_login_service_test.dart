import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/repositories/webauthn_repository.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:rosm_passport_server/src/services/auth_attempts.dart';
import 'package:rosm_passport_server/src/services/passkey_login_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:rosm_passport_server/src/services/webauthn_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockSessions extends Mock implements SessionService {}

class _MockAudit extends Mock implements AuditService {}

class _MockWebAuthn extends Mock implements WebAuthnService {}

void main() {
  const user = UserRecord(
    id: 'user-id',
    email: 'user@example.invalid',
    phoneNumber: null,
    nickname: 'User',
    passwordHash: 'hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );
  const admin = UserRecord(
    id: 'admin-id',
    email: 'admin@example.invalid',
    phoneNumber: null,
    nickname: 'Admin',
    passwordHash: 'hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['admin'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );
  final credential = WebAuthnCredentialRecord(
    userId: user.id,
    credentialId: 'credential-id',
    publicKey: 'public-key',
    counter: 0,
    transports: const ['internal'],
    deviceType: 'singleDevice',
    backedUp: false,
    uvRequired: true,
    uvGraceExpiresAt: null,
    createdAt: DateTime.utc(2026),
  );
  const auth = AuthResult(
    user: AuthenticatedUser(
      id: 'user-id',
      email: 'user@example.invalid',
      nickname: 'User',
      roles: ['user'],
    ),
    tokens: TokenPair(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      tokenType: 'Bearer',
      accessTokenId: 'access-id',
      refreshTokenId: 'refresh-id',
      familyId: 'family-id',
      refreshExpiresIn: 1200,
    ),
  );

  late _MockUsers users;
  late _MockSessions sessions;
  late _MockAudit audit;
  late _MockWebAuthn webAuthn;
  late PasskeyLoginService service;

  setUpAll(() {
    registerFallbackValue(user);
  });

  setUp(() {
    users = _MockUsers();
    sessions = _MockSessions();
    audit = _MockAudit();
    webAuthn = _MockWebAuthn();
    service = PasskeyLoginService(
      userRepository: users,
      sessionService: sessions,
      auditService: audit,
      webAuthnService: webAuthn,
    );
  });

  test('fails closed when WebAuthn is unavailable', () async {
    final disabled = PasskeyLoginService(
      userRepository: users,
      sessionService: sessions,
      auditService: audit,
    );
    final result = await disabled.login(response: const {});
    expect(result.code, 'login_failed');
    expect(result.statusCode, 401);
  });

  test('email-scoped login does not reveal missing accounts', () async {
    when(() => users.findByEmail(any())).thenAnswer((_) async => null);
    final result = await service.login(
      email: 'missing@example.invalid',
      response: const {'id': 'credential-id'},
    );
    expect(result.code, 'login_failed');
  });

  test('discoverable login validates credential and owning user', () async {
    expect((await service.login(response: const {})).code, 'login_failed');
    when(() => webAuthn.findCredential(any())).thenAnswer((_) async => null);
    expect(
      (await service.login(response: const {'rawId': 'missing'})).code,
      'login_failed',
    );
    when(
      () => webAuthn.findCredential('credential-id'),
    ).thenAnswer((_) async => credential);
    when(() => users.findById(user.id)).thenAnswer((_) async => null);
    expect(
      (await service.login(response: const {'id': 'credential-id'})).code,
      'login_failed',
    );
  });

  test('rejects failed verification without issuing a session', () async {
    when(() => users.findByEmail(user.email)).thenAnswer((_) async => user);
    when(
      () => webAuthn.verifyAuthentication(
        userId: any(named: 'userId'),
        email: any(named: 'email'),
        response: any(named: 'response'),
        forceUserVerification: any(named: 'forceUserVerification'),
      ),
    ).thenAnswer((_) async => false);
    expect(
      (await service.login(
        email: user.email,
        response: const {'id': 'credential-id'},
      )).code,
      'login_failed',
    );
    verifyNever(
      () => sessions.issueFirstPartyAuthResult(
        any(),
        postRegistrationPasskeyBootstrap: any(
          named: 'postRegistrationPasskeyBootstrap',
        ),
        rememberMe: any(named: 'rememberMe'),
      ),
    );
  });

  test('successful admin login forces UV and emits an audit event', () async {
    when(() => users.findByEmail(admin.email)).thenAnswer((_) async => admin);
    when(
      () => webAuthn.verifyAuthentication(
        userId: admin.id,
        email: admin.email,
        response: any(named: 'response'),
        forceUserVerification: true,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => sessions.issueFirstPartyAuthResult(
        admin,
        postRegistrationPasskeyBootstrap: any(
          named: 'postRegistrationPasskeyBootstrap',
        ),
        rememberMe: true,
      ),
    ).thenAnswer((_) async => auth);
    when(
      () => audit.log(
        action: any(named: 'action'),
        actorId: any(named: 'actorId'),
        actorType: any(named: 'actorType'),
        resourceType: any(named: 'resourceType'),
        resourceId: any(named: 'resourceId'),
        metadata: any(named: 'metadata'),
        ip: any(named: 'ip'),
      ),
    ).thenAnswer((_) async {});
    final result = await service.login(
      email: admin.email,
      response: const {'id': 'credential-id'},
      requestIp: '127.0.0.1',
      rememberMe: true,
    );
    expect(result.ok, isTrue);
    verify(
      () => audit.log(
        action: 'user.login.webauthn',
        actorId: admin.id,
        actorType: 'user',
        resourceType: 'user',
        resourceId: admin.id,
        metadata: any(named: 'metadata'),
        ip: '127.0.0.1',
      ),
    ).called(1);
  });

  test('discoverable user login verifies without account hints', () async {
    when(
      () => webAuthn.findCredential('credential-id'),
    ).thenAnswer((_) async => credential);
    when(() => users.findById(user.id)).thenAnswer((_) async => user);
    when(
      () => webAuthn.verifyAuthentication(
        userId: null,
        email: null,
        response: any(named: 'response'),
        forceUserVerification: false,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => sessions.issueFirstPartyAuthResult(
        user,
        postRegistrationPasskeyBootstrap: any(
          named: 'postRegistrationPasskeyBootstrap',
        ),
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => auth);
    when(
      () => audit.log(
        action: any(named: 'action'),
        actorId: any(named: 'actorId'),
        actorType: any(named: 'actorType'),
        resourceType: any(named: 'resourceType'),
        resourceId: any(named: 'resourceId'),
        metadata: any(named: 'metadata'),
        ip: any(named: 'ip'),
      ),
    ).thenAnswer((_) async {});
    expect(
      (await service.login(response: const {'id': 'credential-id'})).ok,
      isTrue,
    );
  });
}
