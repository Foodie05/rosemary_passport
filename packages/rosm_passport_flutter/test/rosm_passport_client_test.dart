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

  test('uses WebAuthn origin when requesting passkey options', () async {
    late http.Request captured;
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      webAuthnOrigin: Uri.parse('https://auth.example.com'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'challenge': 'challenge', 'rpId': 'auth.example.com'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final options = await client.beginWebAuthnLogin(email: 'user@example.com');

    expect(options.options['challenge'], 'challenge');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/auth/webauthn/options');
    expect(captured.headers['origin'], 'https://auth.example.com');
    expect(jsonDecode(captured.body), {'email': 'user@example.com'});
  });

  test('generates passkey platform association snippets', () {
    const config = RosmPasskeyPlatformConfig(
      rpDomain: 'auth.cruty.cn',
      appleTeamId: 'Y6AYA4F7T3',
      appleBundleId: 'com.cruos.zion',
      androidPackageName: 'com.cruos.zion',
      androidSha256CertFingerprints: ['AA:BB:CC'],
    );

    expect(config.appleAssociatedDomain, 'webcredentials:auth.cruty.cn');
    expect(config.appleAppSiteAssociation(), {
      'webcredentials': {
        'apps': ['Y6AYA4F7T3.com.cruos.zion'],
      },
    });
    expect(config.androidAssetLinks(), [
      {
        'relation': ['delegate_permission/common.get_login_creds'],
        'target': {
          'namespace': 'android_app',
          'package_name': 'com.cruos.zion',
          'sha256_cert_fingerprints': ['AA:BB:CC'],
        },
      },
    ]);
    expect(config.androidAssetStatementsInclude(), {
      'include': 'https://auth.cruty.cn/.well-known/assetlinks.json',
    });
  });

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

  test('lists and deletes passkeys', () async {
    final requests = <http.Request>[];
    final client = RosmPassportClient(
      issuer: Uri.parse('https://api.example.com'),
      clientId: 'app',
      redirectUri: Uri.parse('com.example.app:/oidc/callback'),
      tokenStore: _MemoryTokenStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'credentials': [
                {
                  'credential_id': 'cred/1',
                  'device_type': 'platform',
                  'backed_up': true,
                  'transports': ['internal'],
                  'created_at': '2026-07-14T12:00:00.000Z',
                },
              ],
              'max_count': 5,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'deleted': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final list = await client.listPasskeys();
    final deleted = await client.deletePasskey(
      list.credentials.first.credentialId,
    );

    expect(list.maxCount, 5);
    expect(list.credentials.single.credentialId, 'cred/1');
    expect(list.credentials.single.backedUp, isTrue);
    expect(deleted.deleted, isTrue);
    expect(requests[0].method, 'GET');
    expect(requests[0].url.path, '/api/v1/me/webauthn/credentials');
    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path, '/api/v1/me/webauthn/credentials/cred%2F1');
  });
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
