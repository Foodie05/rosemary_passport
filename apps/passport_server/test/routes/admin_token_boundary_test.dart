import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import '../../lib/src/config/app_config.dart';
import '../../lib/src/middleware/guards.dart';
import '../../lib/src/repositories/user_repository.dart';
import '../../lib/src/security/token_service.dart';
import '../../lib/src/services/token_validation_service.dart';
import '../../lib/src/utils/auth_cookie.dart';
import '../../routes/api/v1/oidc/native/approve.dart' as native;
import '../../routes/oidc/authorize.dart' as authorize;

class _Users extends Mock implements UserRepository {}

class _Validation extends Mock implements TokenValidationService {}

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

const _admin = UserRecord(
  id: 'admin-id',
  email: 'admin@example.invalid',
  phoneNumber: null,
  nickname: 'Admin',
  passwordHash: 'hash',
  passkeyHash: null,
  securityCodeHash: null,
  authenticatorSecret: null,
  hasAuthenticator: true,
  roles: ['admin'],
  isEmailVerified: true,
  isPhoneVerified: false,
);

void main() {
  late _Users users;
  late _Validation validation;
  final config = AppConfig.forTesting({'OIDC_REQUIRE_PKCE': 'false'});
  setUp(() {
    users = _Users();
    validation = _Validation();
    when(() => users.findById(any())).thenAnswer((_) async => _admin);
  });
  _Context context({
    String client = 'third-party',
    String path = '/api/v1/admin/settings',
    bool cookie = false,
  }) {
    when(() => validation.verifyActiveAccessToken('bearer')).thenAnswer(
      (_) async => VerifiedToken(
        payload: {'sub': _admin.id, 'jti': 'jti', 'client_id': client},
      ),
    );
    when(() => validation.verifyActiveAccessToken('cookie')).thenAnswer(
      (_) async => VerifiedToken(
        payload: {
          'sub': _admin.id,
          'jti': 'cookie-jti',
          'client_id': 'first_party_web',
        },
      ),
    );
    final headers = <String, String>{
      'content-type': 'application/json',
      'authorization': 'Bearer bearer',
      if (cookie) 'cookie': '$kAccessTokenCookieName=cookie',
    };
    final uri = Uri.parse('https://passport.example.invalid$path');
    final request = path.startsWith('/oidc/authorize')
        ? Request.get(uri, headers: headers)
        : Request.post(
            uri,
            body: jsonEncode({
              'client_id': 'rp',
              'redirect_uri': 'https://rp.invalid/callback',
              'response_type': 'code',
            }),
            headers: headers,
          );
    return _Context(request, {
      TokenValidationService: validation,
      UserRepository: users,
      AppConfig: config,
    });
  }

  test(
    'delegated admin token cannot administer Passport or authorize another client',
    () async {
      final ctx = context();
      final adminHandler = requireAdmin()(
        (_) => Response.json(body: {'ok': true}),
      );
      expect((await adminHandler(ctx)).statusCode, 401);
      expect(
        (await native.onRequest(
          context(path: '/api/v1/oidc/native/approve'),
        )).statusCode,
        401,
      );
      final browser = await authorize.onRequest(
        context(path: '/oidc/authorize?client_id=other&response_type=code'),
      );
      expect(browser.statusCode, 302);
      expect(
        (await adminHandler(context(client: 'first_party_web'))).statusCode,
        200,
      );
      expect((await adminHandler(context(cookie: true))).statusCode, 200);
      expect(
        (await currentUser(
          context(client: 'first_party_web', cookie: true),
          requireFirstParty: true,
        ))?.accessTokenId,
        'jti',
      );
      // Documented third-party /me reads must remain usable.
      expect((await currentUser(context()))?.id, _admin.id);
    },
  );
}
