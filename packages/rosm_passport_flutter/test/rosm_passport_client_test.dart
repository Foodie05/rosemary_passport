import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';

void main() {
  test('logger filters levels and forwards records to sinks', () {
    final records = <RosmLogRecord>[];
    final logger = RosmPassportLogger(
      minLevel: RosmLogLevel.warning,
      sinks: [records.add],
    );

    logger.debug('debug ignored', event: 'debug');
    logger.info('info ignored', event: 'info');
    logger.warning('warning kept', event: 'warning');
    logger.error('error kept', event: 'error');

    expect(records.map((record) => record.level), [
      RosmLogLevel.warning,
      RosmLogLevel.error,
    ]);
    expect(records.first.event, 'warning');
    expect(records.last.toJson()['message'], 'error kept');
  });

  test('client emits safe HTTP logs', () async {
    final records = <RosmLogRecord>[];
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      logger: RosmPassportLogger(
        minLevel: RosmLogLevel.debug,
        sinks: [records.add],
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'sent': true, 'message': 'ok'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.sendPasswordRecoveryCode(
      account: 'user@example.com',
      method: RosmPasswordRecoveryMethod.email,
      captchaToken: 'captcha-secret',
    );

    expect(records.map((record) => record.event), contains('http.request'));
    expect(records.map((record) => record.event), contains('http.response'));
    final serialized = records.map((record) => record.toString()).join('\n');
    expect(serialized, isNot(contains('captcha-secret')));
    expect(serialized, isNot(contains('user@example.com')));
  });

  test('sends password recovery code with typed request body', () async {
    late http.Request captured;
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'sent': true, 'message': 'ok'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.sendPasswordRecoveryCode(
      account: 'user@example.com',
      method: RosmPasswordRecoveryMethod.email,
      captchaToken: 'captcha',
    );

    expect(result.sent, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/auth/send-recovery-code');
    expect(jsonDecode(captured.body), {
      'account': 'user@example.com',
      'method': 'email',
      'captcha_token': 'captcha',
    });
  });

  test(
    'exposes a verified registration handoff after email-code login',
    () async {
      final client = RosmPassportClient(
        issuer: Uri.parse('https://api.example.com'),
        clientId: 'app',
        redirectUri: Uri.parse('com.example.app:/oidc/callback'),
        tokenStore: _MemoryTokenStore(),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/email-login');
          return http.Response(
            jsonEncode({
              'error': 'registration_required',
              'message': 'complete registration',
              'registration_handoff': 'signed-handoff',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        client.loginWithEmailCode(
          email: 'new@example.com',
          emailCode: '123456',
        ),
        throwsA(
          isA<RosmApiException>()
              .having((error) => error.code, 'code', 'registration_required')
              .having(
                (error) => error.details['registration_handoff'],
                'handoff',
                'signed-handoff',
              ),
        ),
      );
    },
  );

  test('registers with a verified handoff without a second code', () async {
    late http.Request captured;
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'user-1',
              'email': 'new@example.com',
              'nickname': 'New User',
              'roles': ['user'],
            },
            'security': {},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.registerWithEmail(
      email: 'new@example.com',
      nickname: 'New User',
      password: 'a secure passphrase',
      registrationHandoff: 'signed-handoff',
    );

    expect(captured.url.path, '/api/v1/auth/register');
    expect(jsonDecode(captured.body), {
      'email': 'new@example.com',
      'nickname': 'New User',
      'password': 'a secure passphrase',
      'registration_handoff': 'signed-handoff',
    });
  });

  test('completes a dedicated direct-login step-up challenge', () async {
    late http.Request captured;
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'admin-1',
              'email': 'admin@example.com',
              'nickname': 'Admin',
              'roles': ['admin'],
            },
            'security': {},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.completeLoginStepUp(
      challenge: 'signed-challenge',
      factor: 'authenticator',
      code: '123456',
    );

    expect(captured.url.path, '/api/v1/auth/login-step-up');
    expect(jsonDecode(captured.body), {
      'step_up_challenge': 'signed-challenge',
      'factor': 'authenticator',
      'code': '123456',
    });
  });

  test('resets password by code with typed request body', () async {
    late http.Request captured;
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'updated': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.resetPasswordByCode(
      account: '+15551234567',
      method: RosmPasswordRecoveryMethod.phone,
      code: '123456',
      newPassword: 'new-password',
    );

    expect(result.updated, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/auth/reset-password-by-code');
    expect(jsonDecode(captured.body), {
      'account': '+15551234567',
      'method': 'phone',
      'code': '123456',
      'new_password': 'new-password',
    });
  });

  test('sends an optional admin password with email-code login', () async {
    late http.Request captured;
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      lastSignInStore: RosmMemoryLastSignInStore(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'admin-1',
              'email': 'admin@example.com',
              'nickname': 'Admin',
              'roles': ['admin'],
            },
            'security': {},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.loginWithEmailCode(
      email: 'admin@example.com',
      emailCode: '123456',
      password: 'admin-password',
    );

    expect(captured.url.path, '/api/v1/auth/email-login');
    expect(jsonDecode(captured.body), {
      'email': 'admin@example.com',
      'email_code': '123456',
      'password': 'admin-password',
    });
  });

  test(
    'remembers only the last successful login method and identifier',
    () async {
      final hints = RosmMemoryLastSignInStore();
      final client = RosmPassportClient(
        issuer: Uri.parse('https://api.example.com'),
        clientId: 'app',
        redirectUri: Uri.parse('com.example.app:/oidc/callback'),
        tokenStore: _MemoryTokenStore(),
        lastSignInStore: hints,
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user-1',
                'email': 'user@example.com',
                'nickname': 'User',
                'roles': ['user'],
              },
              'security': {},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.loginWithEmailCode(
        email: 'user@example.com',
        emailCode: '123456',
      );

      final hint = await client.lastSignIn();
      expect(hint?.method, RosmSignInMethod.emailCode);
      expect(hint?.identifier, 'user@example.com');
      await client.clearLastSignIn();
      expect(await client.lastSignIn(), isNull);
    },
  );

  test(
    'reads configured Aliyun captcha details from the public endpoint',
    () async {
      final client = RosmPassportClient(
        issuer: Uri.parse('https://api.example.com'),
        clientId: 'app',
        redirectUri: Uri.parse('com.example.app:/oidc/callback'),
        tokenStore: _MemoryTokenStore(),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/public/config');
          return http.Response(
            jsonEncode({
              'captcha': {
                'provider': 'aliyun',
                'prefix': 'abc123',
                'scene_id': 'login01',
                'region': 'cn',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final config = await client.aliyunCaptchaConfig();

      expect(config?.prefix, 'abc123');
      expect(config?.sceneId, 'login01');
      expect(config?.region, 'cn');
    },
  );

  test(
    'completes server handoff with authorization code and verifier',
    () async {
      late http.Request captured;
      final client = RosmPassportClient(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'com.example.app',
        redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
        tokenStore: _MemoryTokenStore(),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'session_token': 'app-session'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final authRequest = client.createAuthorizationRequest(
        state: 'state-1',
        nonce: 'nonce-1',
        serverHandoff: true,
      );
      final approval = RosmAuthorizationApproval(
        code: 'code-1',
        state: 'state-1',
        redirectUri: authRequest.redirectUri,
        callbackUrl: authRequest.redirectUri.replace(
          queryParameters: {'code': 'code-1', 'state': 'state-1'},
        ),
      );

      final result = await client.completeServerHandoff(
        endpoint: Uri.parse('https://api.example.com/auth/rosm/sdk/complete'),
        request: authRequest,
        approval: approval,
        headers: const {'x-app': 'zion'},
        extra: const {'device_id': 'device-1'},
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(result.payload['session_token'], 'app-session');
      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://api.example.com/auth/rosm/sdk/complete',
      );
      expect(captured.headers['x-app'], 'zion');
      expect(body['issuer'], 'https://auth.example.com');
      expect(body['client_id'], 'com.example.app');
      expect(
        body['redirect_uri'],
        'https://api.example.com/auth/rosm/callback',
      );
      expect(body['code'], 'code-1');
      expect(body['state'], 'state-1');
      expect(body['nonce'], 'nonce-1');
      expect(body['code_verifier'], authRequest.codeVerifier);
      expect(body['extra'], {'device_id': 'device-1'});
    },
  );

  test('uses server error code as fallback message', () async {
    final client = RosmPassportClient(
      issuer: Uri.parse('https://auth.example.com'),
      clientId: 'com.example.app',
      redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'invalid state'}),
          400,
          headers: {'content-type': 'application/json'},
          reasonPhrase: 'Bad Request',
        );
      }),
    );
    final authRequest = client.createAuthorizationRequest(
      state: 'state-1',
      nonce: 'nonce-1',
      serverHandoff: true,
    );
    final approval = RosmAuthorizationApproval(
      code: 'code-1',
      state: 'state-1',
      redirectUri: authRequest.redirectUri,
      callbackUrl: authRequest.redirectUri.replace(
        queryParameters: {'code': 'code-1', 'state': 'state-1'},
      ),
    );

    await expectLater(
      client.completeServerHandoff(
        endpoint: Uri.parse('https://api.example.com/auth/rosm/sdk/complete'),
        request: authRequest,
        approval: approval,
      ),
      throwsA(
        isA<RosmApiException>().having(
          (error) => error.message,
          'message',
          '授权会话已失效，请重新登录后再试。',
        ),
      ),
    );
  });

  test(
    'refreshes access token once after unauthorized account request',
    () async {
      final requests = <http.Request>[];
      final store = _MemoryTokenStore()
        .._tokens = const RosmTokenSet(
          accessToken: 'old-access',
          refreshToken: 'refresh-1',
          tokenType: 'Bearer',
          expiresIn: 3600,
        );
      final client = RosmPassportClient(
        issuer: Uri.parse('https://api.example.com'),
        clientId: 'app',
        redirectUri: Uri.parse('com.example.app:/oidc/callback'),
        tokenStore: store,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/v1/me' && requests.length == 1) {
            return http.Response(
              jsonEncode({'error': 'unauthorized'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/oidc/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'new-access',
                'refresh_token': 'refresh-2',
                'token_type': 'Bearer',
                'expires_in': 3600,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user-1',
                'email': 'user@example.com',
                'nickname': 'User',
                'roles': ['user'],
              },
              'security': {
                'has_password': true,
                'has_authenticator': false,
                'has_phone': false,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final account = await client.account();

      expect(account.user.id, 'user-1');
      expect(requests.map((request) => request.url.path), [
        '/api/v1/me',
        '/oidc/token',
        '/api/v1/me',
      ]);
      expect(requests.last.headers['authorization'], 'Bearer new-access');
      expect((await store.read())?.refreshToken, 'refresh-2');
    },
  );

  test(
    'shares one refresh-token rotation across concurrent requests',
    () async {
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      var refreshRequests = 0;
      var accountRequests = 0;
      final store = _MemoryTokenStore()
        .._tokens = const RosmTokenSet(
          accessToken: 'old-access',
          refreshToken: 'refresh-1',
          tokenType: 'Bearer',
          expiresIn: 3600,
        );
      final client = RosmPassportClient(
        issuer: Uri.parse('https://api.example.com'),
        clientId: 'app',
        redirectUri: Uri.parse('com.example.app:/oidc/callback'),
        tokenStore: store,
        httpClient: MockClient((request) async {
          if (request.url.path == '/oidc/token') {
            refreshRequests += 1;
            refreshStarted.complete();
            await releaseRefresh.future;
            return http.Response(
              jsonEncode({
                'access_token': 'new-access',
                'refresh_token': 'refresh-2',
                'token_type': 'Bearer',
                'expires_in': 3600,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/me') {
            accountRequests += 1;
            if (request.headers['authorization'] == 'Bearer old-access') {
              return http.Response(
                jsonEncode({'error': 'unauthorized'}),
                401,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'user-1',
                  'email': 'user@example.com',
                  'nickname': 'User',
                  'roles': ['user'],
                },
                'security': {},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final first = client.account();
      final second = client.account();
      await refreshStarted.future;
      expect(accountRequests, 2);
      expect(refreshRequests, 1);

      releaseRefresh.complete();
      final accounts = await Future.wait([first, second]);
      expect(accounts.map((account) => account.user.id), ['user-1', 'user-1']);
      expect(refreshRequests, 1);
      expect(accountRequests, 4);
      expect((await store.read())?.refreshToken, 'refresh-2');
    },
  );
}

class _MemoryTokenStore implements RosmTokenStore {
  RosmTokenSet? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<RosmTokenSet?> read() async => _tokens;

  @override
  Future<void> save(RosmTokenSet tokens) async {
    _tokens = tokens;
  }
}
