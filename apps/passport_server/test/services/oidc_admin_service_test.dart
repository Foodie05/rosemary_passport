import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/repositories/oidc_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/services/oidc_admin_service.dart';
import 'package:test/test.dart';

class _Repository extends Mock implements OidcRepository {}

class _Hasher extends Mock implements PasswordHasher {}

void main() {
  late _Repository repository;
  late OidcAdminService service;

  setUp(() {
    repository = _Repository();
    service = OidcAdminService(repository, _Hasher());
    when(
      () => repository.findClient(any()),
    ).thenAnswer((_) async => {'client_secret_hash': 'existing-hash'});
    when(
      () => repository.upsertClient(
        clientId: any(named: 'clientId'),
        displayName: any(named: 'displayName'),
        isOfficial: any(named: 'isOfficial'),
        redirectUris: any(named: 'redirectUris'),
        scopes: any(named: 'scopes'),
        grantTypes: any(named: 'grantTypes'),
        isConfidential: any(named: 'isConfidential'),
        isActive: any(named: 'isActive'),
        clientSecretHash: any(named: 'clientSecretHash'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<OidcClientUpsertResult> save(
    List<String> uris, {
    required bool confidential,
  }) => service.upsertClient(
    clientId: 'com.cruty.stockme',
    displayName: 'Stockme',
    isOfficial: false,
    redirectUris: uris,
    scopes: ['openid'],
    grantTypes: ['authorization_code'],
    isConfidential: confidential,
    isActive: true,
  );

  test(
    'explains a confidential custom-scheme conflict before any DB work',
    () async {
      await expectLater(
        save([
          'https://api.example.com/callback',
          'com.cruty.stockme:/oidc/callback',
        ], confidential: true),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            '机密客户端的回调地址必须使用 HTTPS 或本机回环 HTTP，不能使用自定义 scheme。',
          ),
        ),
      );
      verifyNever(() => repository.findClient(any()));
    },
  );

  test(
    'keeps valid public App and confidential server callbacks supported',
    () async {
      await save(['com.cruty.stockme:/oidc/callback'], confidential: false);
      await save([
        'https://api.example.com/callback',
        'http://localhost:8080/callback',
        'http://127.0.0.1:8080/callback',
      ], confidential: true);
      verify(() => repository.findClient('com.cruty.stockme')).called(2);
    },
  );

  test(
    'describes invalid public redirects without accepting unsafe schemes',
    () async {
      for (final uri in [
        'javascript:alert(1)',
        'http://example.com/callback',
        'https://example.com/callback#fragment',
      ]) {
        await expectLater(
          save([uri], confidential: false),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('回调地址须使用 HTTPS'),
            ),
          ),
        );
      }
      verifyNever(() => repository.findClient(any()));
    },
  );
}
