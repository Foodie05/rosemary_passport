import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/services/helper_client.dart';
import 'package:test/test.dart';

void main() {
  test('disabled helper fails closed and reports unhealthy', () async {
    final client = HelperClient(
      AppConfig.forTesting(const {}),
      MockClient((_) async {
        fail('disabled helper must not perform HTTP requests');
      }),
    );
    expect(client.enabled, isFalse);
    await expectLater(client.execute('script', const {}), throwsStateError);
    expect(await client.healthCheck(), isFalse);
    client.close();
  });

  test(
    'execute authenticates, serializes payload, and resets failures',
    () async {
      late http.Request captured;
      final client = HelperClient(
        AppConfig.forTesting(const {
          'HELPER_BASE_URL': 'http://helper.internal:3000',
          'HELPER_SHARED_KEY': 'shared-key',
          'HELPER_TIMEOUT_SECONDS': '1',
        }),
        MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true, 'value': 42}), 200);
        }),
      );
      expect(client.enabled, isTrue);
      expect(await client.execute('verify.mjs', const {'input': 'value'}), {
        'ok': true,
        'value': 42,
      });
      expect(captured.url.path, '/v1/execute');
      expect(captured.headers['authorization'], 'Bearer shared-key');
      expect(jsonDecode(captured.body), {
        'script': 'verify.mjs',
        'payload': {'input': 'value'},
      });
      client.close();
    },
  );

  test('health check handles success, failure, and transport errors', () async {
    final config = AppConfig.forTesting(const {
      'HELPER_BASE_URL': 'http://helper.internal:3000',
      'HELPER_TIMEOUT_SECONDS': '1',
    });
    expect(
      await HelperClient(
        config,
        MockClient((_) async => http.Response('', 200)),
      ).healthCheck(),
      isTrue,
    );
    expect(
      await HelperClient(
        config,
        MockClient((_) async => http.Response('', 503)),
      ).healthCheck(),
      isFalse,
    );
    expect(
      await HelperClient(
        config,
        MockClient((_) async => throw Exception('down')),
      ).healthCheck(),
      isFalse,
    );
  });

  test('three execution failures open the circuit', () async {
    var requests = 0;
    final client = HelperClient(
      AppConfig.forTesting(const {
        'HELPER_BASE_URL': 'http://helper.internal:3000',
        'HELPER_TIMEOUT_SECONDS': '1',
      }),
      MockClient((_) async {
        requests++;
        return http.Response('unavailable', 503);
      }),
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      await expectLater(
        client.execute('verify.mjs', const {}),
        throwsStateError,
      );
    }
    await expectLater(client.execute('verify.mjs', const {}), throwsStateError);
    expect(requests, 3);
  });
}
