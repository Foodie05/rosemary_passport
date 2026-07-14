import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';

void main() {
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
