import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';

void main() {
  const policy = RosmPasswordPolicy();
  test('standalone SDK matches web and backend acceptance fixtures', () {
    final cases =
        jsonDecode(
              File(
                'test/fixtures/password-policy-cases.json',
              ).readAsStringSync(),
            )
            as List;
    for (final item in cases) {
      expect(
        policy.evaluate(item['input'] as String).ok,
        item['accepted'],
        reason: item['name'] as String?,
      );
    }
  });
  test(
    'categories distinguish letters, numbers and punctuation, not case or spaces',
    () {
      for (final value in ['Abcdefg1', 'Abcdefg!', '7291046!']) {
        expect(policy.evaluate(value).ok, isTrue);
      }
      for (final value in ['aBcDeFgH', 'abc defg', 'Abcdef1']) {
        expect(policy.evaluate(value).ok, isFalse);
      }
      expect(policy.evaluate('orchid').message, contains('还需 2 个'));
      expect(policy.evaluate('x' * 129).message, contains('最多 128'));
      expect(
        policy.containsPersonalInfo('maria blooms!', ['maria@example.com']),
        isTrue,
      );
    },
  );
  test('all new-password client methods reject locally without HTTP', () async {
    var requests = 0;
    final client = _client(
      MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    final invalid = <Future<Object?>>[
      client.registerWithEmail(
        email: 'new@example.com',
        nickname: 'New',
        password: 'aBcDeFgH',
      ),
      client.registerWithPhone(
        phoneNumber: '13800138000',
        nickname: 'New',
        password: 'aBcDeFgH',
      ),
      client.resetOwnPassword(newPassword: 'aBcDeFgH', emailCode: '123456'),
      client.resetPasswordByCode(
        account: 'new@example.com',
        method: RosmPasswordRecoveryMethod.email,
        code: '123456',
        newPassword: 'aBcDeFgH',
      ),
      client.updateAccount(newPassword: 'aBcDeFgH'),
    ];
    // Attach all handlers before awaiting; no unhandled future errors.
    await Future.wait(
      invalid.map(
        (future) => expectLater(
          future,
          throwsA(
            isA<RosmApiException>().having(
              (e) => e.code,
              'code',
              'password_policy_violation',
            ),
          ),
        ),
      ),
    );
    expect(requests, 0);
  });
  test(
    'valid interior spaces are sent unchanged and legacy login is unrestricted',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = _client(
        MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'new',
                'email': 'new@example.com',
                'nickname': 'New',
                'roles': [],
              },
              'security': {},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.registerWithEmail(
        email: 'new@example.com',
        nickname: 'New',
        password: 'orchid willow!',
      );
      await client.loginWithPassword(email: 'old@example.com', password: '旧密码');
      expect(bodies[0]['input'], 'orchid willow!');
      expect(bodies[1]['input'], '旧密码');
    },
  );
}

RosmPassportClient _client(http.Client httpClient) => RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'example',
  redirectUri: Uri.parse('example:/callback'),
  tokenStore: RosmMemoryTokenStore(),
  lastSignInStore: RosmMemoryLastSignInStore(),
  httpClient: httpClient,
);
