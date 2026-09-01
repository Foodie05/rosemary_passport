import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';

import '../../lib/src/config/app_config.dart';
import '../../routes/oidc/authorize.dart' as route;

class _TestRequestContext implements RequestContext {
  _TestRequestContext(this.request, this.config);

  @override
  final Request request;
  final AppConfig config;

  @override
  Map<String, String> get mountedParams => const {};

  @override
  RequestContext provide<T extends Object?>(T Function() create) =>
      throw UnsupportedError('provide is not used by this test');

  @override
  T read<T>() {
    if (T == AppConfig) {
      return config as T;
    }
    throw StateError('Unexpected dependency: $T');
  }
}

void main() {
  test(
    'unauthenticated authorization resumes through an internal web path',
    () async {
      final config = AppConfig.forTesting({
        'SERVER_BASE_URL': 'https://apiauth.example.test',
        'WEB_BASE_URL': 'https://auth.example.test',
      });
      final context = _TestRequestContext(
        Request.get(
          Uri.parse(
            'https://apiauth.example.test/oidc/authorize'
            '?client_id=test&redirect_uri=https%3A%2F%2Fclient.example%2Fcallback'
            '&response_type=code&scope=openid%20profile%20email%20phone%20accountRule'
            '&state=state-value&nonce=nonce-value'
            '&code_challenge=pkce-challenge&code_challenge_method=S256',
          ),
        ),
        config,
      );

      final response = await route.onRequest(context);
      final location = Uri.parse(response.headers['location']!);
      final next = Uri.parse(location.queryParameters['next']!);

      expect(response.statusCode, 302);
      expect(location.origin, 'https://auth.example.test');
      expect(location.path, '/login');
      expect(next.path, '/oidc/continue');
      expect(next.queryParameters['client_id'], 'test');
      expect(
        next.queryParameters['redirect_uri'],
        'https://client.example/callback',
      );
      expect(next.queryParameters['response_type'], 'code');
      expect(
        next.queryParameters['scope'],
        'openid profile email phone accountRule',
      );
      expect(next.queryParameters['state'], 'state-value');
      expect(next.queryParameters['nonce'], 'nonce-value');
      expect(next.queryParameters['code_challenge'], 'pkce-challenge');
      expect(next.queryParameters['code_challenge_method'], 'S256');
    },
  );

  test(
    'authorization confirmation blocks duplicate approval submissions',
    () async {
      final config = AppConfig.forTesting({
        'SERVER_BASE_URL': 'https://apiauth.example.test',
        'WEB_BASE_URL': 'https://auth.example.test',
      });
      final context = _TestRequestContext(
        Request.get(
          Uri.parse(
            'https://apiauth.example.test/oidc/authorize'
            '?client_id=test&response_type=code',
          ),
        ),
        config,
      );

      final response = route.authorizationConsentPage(
        context,
        clientDisplayName: '测试应用',
        isOfficial: false,
        scopeLines: const ['基础资料（昵称）'],
        consentToken: 'consent-token',
      );

      expect(response.statusCode, 200);
      expect(
        await response.body(),
        allOf(
          contains('id="approve-button"'),
          contains("approveButton.dataset.submitting === 'true'"),
          contains("approveButton.setAttribute('aria-disabled', 'true')"),
          contains('授权处理中…'),
        ),
      );
    },
  );
}
