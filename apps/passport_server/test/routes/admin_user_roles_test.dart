import 'dart:io';
import '../../lib/src/security/password_policy.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import '../../lib/src/config/app_config.dart';
import '../../lib/src/models/authenticated_user.dart';
import '../../lib/src/repositories/user_repository.dart';
import '../../lib/src/services/auth_service.dart';
import '../../lib/src/services/audit_service.dart';
import '../../routes/api/v1/admin/users/[id]/roles.dart' as role_route;
import '../../routes/api/v1/admin/users/index.dart' as users_route;

class _Request extends Mock implements Request {}

class _Connection extends Mock implements HttpConnectionInfo {}

class _Users extends Mock implements UserRepository {}

class _Auth extends Mock implements AuthService {}

class _Audit extends Mock implements AuditService {}

class _Context implements RequestContext {
  _Context(this.request, this.dependencies);
  @override
  final Request request;
  final Map<Type, Object?> dependencies;
  @override
  Map<String, String> get mountedParams => const {};
  @override
  T read<T>() => dependencies[T] as T;
  @override
  RequestContext provide<T extends Object?>(T Function() create) =>
      _Context(request, {...dependencies, T: create()});
}

const actor = AuthenticatedUser(
  id: 'admin-id',
  email: 'admin@example.invalid',
  nickname: 'Admin',
  roles: ['admin'],
);
const target = UserRecord(
  id: 'target-id',
  email: 'target@example.invalid',
  phoneNumber: null,
  nickname: 'Target',
  passwordHash: 'hash',
  passkeyHash: null,
  securityCodeHash: null,
  authenticatorSecret: null,
  hasAuthenticator: false,
  roles: ['user'],
  isEmailVerified: true,
  isPhoneVerified: false,
);
void main() {
  late _Users users;
  late _Auth auth;
  late _Audit audit;
  setUp(() {
    users = _Users();
    auth = _Auth();
    audit = _Audit();
    when(() => users.findById('target-id')).thenAnswer((_) async => target);
    when(() => users.findByEmail(any())).thenAnswer((_) async => null);
    when(
      () => users.updateRoles(
        userId: any(named: 'userId'),
        roles: any(named: 'roles'),
        adminActorId: any(named: 'adminActorId'),
      ),
    ).thenAnswer((_) async {});
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
  });
  _Context context(
    Map<String, dynamic> body, {
    AuthenticatedUser acting = actor,
    bool create = false,
  }) {
    final request = _Request();
    final connection = _Connection();
    when(
      () => connection.remoteAddress,
    ).thenReturn(InternetAddress.loopbackIPv4);
    when(() => request.connectionInfo).thenReturn(connection);
    when(
      () => request.method,
    ).thenReturn(create ? HttpMethod.post : HttpMethod.patch);
    when(() => request.uri).thenReturn(
      Uri.parse('https://epass.invalid/api/v1/admin/users/target-id/roles'),
    );
    when(
      () => request.headers,
    ).thenReturn({'content-type': 'application/json'});
    when(() => request.json()).thenAnswer((_) async => body);
    return _Context(request, {
      AuthenticatedUser: acting,
      UserRepository: users,
      AuthService: auth,
      AuditService: audit,
      AppConfig: AppConfig.forTesting({}),
      PasswordPolicy: PasswordPolicy(),
    });
  }

  void verifyProof(bool ok) {
    when(
      () => auth.verifyStepUp(
        userId: actor.id,
        excludedFactor: 'password',
        proof: any(named: 'proof'),
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer(
      (_) async => ok
          ? const CredentialActionAttempt.success()
          : const CredentialActionAttempt.failure(
              code: 'verification_failed',
              message: '二次验证失败。',
              statusCode: 401,
            ),
    );
  }

  test('ordinary actors cannot alter roles even with a proof', () async {
    final result = await role_route.onRequest(
      context(
        {
          'roles': ['admin'],
          'verification': {'method': 'email_code', 'code': '123456'},
        },
        acting: const AuthenticatedUser(
          id: 'user-id',
          email: 'u@example.invalid',
          nickname: 'U',
          roles: ['user'],
        ),
      ),
      'target-id',
    );
    expect(result.statusCode, 403);
    verifyZeroInteractions(auth);
    verifyZeroInteractions(users);
    verifyZeroInteractions(audit);
  });
  test('missing or password-only MFA makes no role write', () async {
    for (final proof in [
      null,
      {'method': 'password', 'password': 'correct'},
    ]) {
      final result = await role_route.onRequest(
        context({
          'roles': ['admin'],
          'verification': proof,
        }),
        'target-id',
      );
      expect(result.statusCode, 401);
    }
    verifyZeroInteractions(auth);
    verifyNever(
      () => users.updateRoles(
        userId: any(named: 'userId'),
        roles: any(named: 'roles'),
        adminActorId: any(named: 'adminActorId'),
      ),
    );
    verifyZeroInteractions(audit);
  });
  test('invalid choices do not consume MFA', () async {
    for (final roles in [
      [],
      ['owner'],
    ]) {
      expect(
        (await role_route.onRequest(
          context({
            'roles': roles,
            'verification': {'method': 'email_code', 'code': '123456'},
          }),
          'target-id',
        )).statusCode,
        400,
      );
    }
    verifyZeroInteractions(auth);
  });
  test('failed MFA makes no role write or audit event', () async {
    verifyProof(false);
    expect(
      (await role_route.onRequest(
        context({
          'roles': ['admin'],
          'verification': {'method': 'authenticator', 'code': '000000'},
        }),
        'target-id',
      )).statusCode,
      401,
    );
    verifyNever(
      () => users.updateRoles(
        userId: any(named: 'userId'),
        roles: any(named: 'roles'),
        adminActorId: any(named: 'adminActorId'),
      ),
    );
    verifyZeroInteractions(audit);
  });
  test(
    'all four MFA methods use the acting admin and guard the atomic write',
    () async {
      verifyProof(true);
      for (final method in [
        'email_code',
        'phone_code',
        'authenticator',
        'passkey',
      ]) {
        final response = await role_route.onRequest(
          context({
            'roles': ['user', 'admin'],
            'actor_id': 'target-id',
            'verification': {
              'method': method,
              'code': '123456',
              'response': {'id': 'credential'},
            },
          }),
          'target-id',
        );
        expect(response.statusCode, 200);
      }
      verify(
        () => users.updateRoles(
          userId: 'target-id',
          roles: ['user', 'admin'],
          adminActorId: actor.id,
        ),
      ).called(4);
      verify(
        () => auth.verifyStepUp(
          userId: actor.id,
          excludedFactor: 'password',
          proof: any(named: 'proof'),
          requestIp: any(named: 'requestIp'),
        ),
      ).called(4);
    },
  );
  test(
    'revoked admin authority fails after MFA without a success audit',
    () async {
      verifyProof(true);
      when(
        () => users.updateRoles(
          userId: any(named: 'userId'),
          roles: any(named: 'roles'),
          adminActorId: any(named: 'adminActorId'),
        ),
      ).thenThrow(AdminRoleAssignmentDenied());
      expect(
        (await role_route.onRequest(
          context({
            'roles': ['admin'],
            'verification': {'method': 'email_code', 'code': '123456'},
          }),
          'target-id',
        )).statusCode,
        403,
      );
      verifyZeroInteractions(audit);
    },
  );
  test(
    'creating an admin cannot bypass MFA through the create route',
    () async {
      expect(
        (await users_route.onRequest(
          context({
            'email': 'new@example.invalid',
            'nickname': 'New',
            'password': ['Example', 'Only', '42!'].join(),
            'roles': ['admin'],
          }, create: true),
        )).statusCode,
        401,
      );
      verifyZeroInteractions(auth);
      verifyNever(
        () => users.createUser(
          userId: any(named: 'userId'),
          email: any(named: 'email'),
          nickname: any(named: 'nickname'),
          passwordHash: any(named: 'passwordHash'),
          roles: any(named: 'roles'),
          isEmailVerified: any(named: 'isEmailVerified'),
          adminActorId: any(named: 'adminActorId'),
        ),
      );
    },
  );
}
