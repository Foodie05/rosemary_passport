import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../lib/src/config/app_config.dart';
import '../../lib/src/models/authenticated_user.dart';
import '../../lib/src/repositories/security_repository.dart';
import '../../lib/src/services/audit_service.dart';
import '../../routes/api/v1/admin/status/cooldowns/index.dart' as route;

class _Security extends Mock implements SecurityRepository {}

class _Audit extends Mock implements AuditService {}

class _Request extends Mock implements Request {}

class _ConnectionInfo extends Mock implements HttpConnectionInfo {}

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

const _admin = AuthenticatedUser(
  id: 'admin-id',
  email: 'admin@example.invalid',
  nickname: 'Admin',
  roles: ['admin'],
);

void main() {
  late _Security security;
  late _Audit audit;

  setUp(() {
    security = _Security();
    audit = _Audit();
  });

  _Context context(Request request) => _Context(request, {
    SecurityRepository: security,
    AuditService: audit,
    AuthenticatedUser: _admin,
    AppConfig: AppConfig.forTesting({}),
  });

  test(
    'lists email phone and IP throttles, including unknown identities',
    () async {
      final now = DateTime.utc(2026, 9, 19, 1);
      when(
        () => security.listVerificationCodeThrottles(
          limit: 25,
          offset: 0,
          search: '',
          subjectType: 'all',
          activeOnly: false,
        ),
      ).thenAnswer(
        (_) async => ThrottlePage(
          total: 2,
          records: [
            ThrottleRecord(
              scope: 'verification-code:login:email',
              subject: 'not-registered@example.invalid',
              subjectType: 'email',
              hits: 4,
              windowStartedAt: now,
              blockedUntil: now.add(const Duration(minutes: 10)),
              updatedAt: now.add(const Duration(minutes: 1)),
              isActive: true,
              remainingSeconds: 540,
            ),
            ThrottleRecord(
              scope: 'verification-code:send:ip',
              subject: '203.0.113.42',
              subjectType: 'ip',
              hits: 2,
              windowStartedAt: now,
              updatedAt: now,
              isActive: false,
              remainingSeconds: 0,
            ),
          ],
        ),
      );

      final response = await route.onRequest(
        context(
          Request.get(
            Uri.parse('https://passport.invalid/api/v1/admin/status/cooldowns'),
          ),
        ),
      );
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      final records = body['cooldowns'] as List<dynamic>;

      expect(response.statusCode, 200);
      expect(response.headers['cache-control'], 'no-store');
      expect(records, hasLength(2));
      expect(
        records.first,
        containsPair('subject', 'not-registered@example.invalid'),
      );
      expect(records.first, containsPair('hits', 4));
      expect(records.first, containsPair('remaining_seconds', 540));
      expect(records.last, containsPair('subject_type', 'ip'));
      expect(records.last, containsPair('subject', '203.0.113.42'));
    },
  );

  test('rejects unsupported subject filters before querying storage', () async {
    final response = await route.onRequest(
      context(
        Request.get(
          Uri.parse(
            'https://passport.invalid/api/v1/admin/status/cooldowns'
            '?subject_type=username',
          ),
        ),
      ),
    );

    expect(response.statusCode, 400);
    verifyNever(
      () => security.listVerificationCodeThrottles(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        search: any(named: 'search'),
        subjectType: any(named: 'subjectType'),
        activeOnly: any(named: 'activeOnly'),
      ),
    );
  });

  test(
    'reset is atomic and audit metadata never contains the identity',
    () async {
      const scope = 'verification-code:login:email';
      const subject = 'person@example.invalid';
      final request = _Request();
      final connection = _ConnectionInfo();
      when(() => request.method).thenReturn(HttpMethod.delete);
      when(() => request.json()).thenAnswer(
        (_) async => <String, dynamic>{'scope': scope, 'subject': subject},
      );
      when(() => request.connectionInfo).thenReturn(connection);
      when(
        () => connection.remoteAddress,
      ).thenReturn(InternetAddress.loopbackIPv4);
      when(() => request.headers).thenReturn(const {});
      when(
        () => security.deleteVerificationCodeThrottle(
          scope: scope,
          subject: subject,
        ),
      ).thenAnswer((_) async => true);
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

      final response = await route.onRequest(context(request));

      expect(response.statusCode, 200);
      verify(
        () => security.deleteVerificationCodeThrottle(
          scope: scope,
          subject: subject,
        ),
      ).called(1);
      final captured = verify(
        () => audit.log(
          action: 'admin.cooldown.reset',
          actorId: _admin.id,
          actorType: 'admin',
          resourceType: 'verification_code_throttle',
          resourceId: captureAny(named: 'resourceId'),
          metadata: captureAny(named: 'metadata'),
          ip: '127.0.0.1',
        ),
      ).captured;
      expect(captured.first, scope);
      final metadata = captured.last as Map<String, dynamic>;
      expect(metadata, {'scope': scope, 'subject_type': 'email'});
      expect(metadata.toString(), isNot(contains(subject)));
    },
  );
}
