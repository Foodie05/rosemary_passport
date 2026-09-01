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
            '&response_type=code&state=state-value',
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
      expect(next.queryParameters['state'], 'state-value');
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
