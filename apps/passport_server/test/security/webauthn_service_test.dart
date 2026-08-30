import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/repositories/webauthn_repository.dart';
import 'package:rosm_passport_server/src/services/helper_client.dart';
import 'package:rosm_passport_server/src/services/webauthn_service.dart';
import 'package:test/test.dart';

class _MockRepository extends Mock implements WebAuthnRepository {}

class _MockHelper extends Mock implements HelperClient {}

void main() {
  final credential = WebAuthnCredentialRecord(
    userId: 'user-id',
    credentialId: 'credential-id',
    publicKey: 'public-key',
    counter: 7,
    transports: const ['internal'],
    deviceType: 'singleDevice',
    backedUp: false,
    uvRequired: false,
    uvGraceExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    createdAt: DateTime.utc(2026),
  );
  final challenge = WebAuthnChallengeRecord(
    id: 'challenge-id',
    challenge: 'challenge',
    rpId: 'passport.example.invalid',
    origin: 'https://passport.example.invalid',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
  );
  late _MockRepository repository;
  late _MockHelper helper;
  late WebAuthnService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    repository = _MockRepository();
    helper = _MockHelper();
    when(() => helper.enabled).thenReturn(true);
    service = WebAuthnService(
      config: AppConfig.forTesting(const {
        'SERVER_BASE_URL': 'https://passport.example.invalid',
        'WEBAUTHN_ANDROID_ORIGINS': 'android:apk-key-hash:test',
      }),
      repository: repository,
      helperClient: helper,
    );
  });

  test('health and credential management delegate safely', () async {
    when(() => helper.healthCheck()).thenAnswer((_) async => true);
    expect(await service.healthCheck(), isTrue);
    when(
      () => repository.listCredentialsForUser('user-id'),
    ).thenAnswer((_) async => [credential]);
    when(
      () => repository.countCredentialsForUser('user-id'),
    ).thenAnswer((_) async => 1);
    when(
      () => repository.deleteCredential(
        userId: 'user-id',
        credentialId: 'credential-id',
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.findCredential('credential-id'),
    ).thenAnswer((_) async => credential);
    expect(await service.hasCredentials('user-id'), isTrue);
    expect(await service.countCredentials('user-id'), 1);
    expect(await service.listCredentials('user-id'), [
      {
        'credential_id': 'credential-id',
        'device_type': 'singleDevice',
        'backed_up': false,
        'transports': ['internal'],
        'created_at': DateTime.utc(2026).toIso8601String(),
      },
    ]);
    await service.deleteCredential(
      userId: 'user-id',
      credentialId: 'credential-id',
    );
    expect(await service.findCredential('credential-id'), credential);
    when(
      () => repository.listCredentialsForUser('empty'),
    ).thenAnswer((_) async => []);
    expect(await service.hasCredentials('empty'), isFalse);
  });

  test('registration options exclude existing credentials', () async {
    when(
      () => repository.listCredentialsForUser('user-id'),
    ).thenAnswer((_) async => [credential]);
    when(
      () => helper.execute('webauthn-register-options.mjs', any()),
    ).thenAnswer((_) async => {'challenge': 'new-challenge'});
    when(
      () => repository.storeChallenge(
        userId: 'user-id',
        email: any(named: 'email'),
        purpose: 'register',
        challenge: 'new-challenge',
        rpId: 'passport.example.invalid',
        origin: 'https://passport.example.invalid',
        expiresAt: any(named: 'expiresAt'),
      ),
    ).thenAnswer((_) async {});
    final result = await service.generateRegistrationOptions(
      userId: 'user-id',
      email: 'user@example.invalid',
      nickname: 'User',
      origin: 'https://passport.example.invalid',
    );
    expect(result['challenge'], 'new-challenge');
    final payload =
        verify(
              () =>
                  helper.execute('webauthn-register-options.mjs', captureAny()),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload['excludeCredentials'], [
      {
        'id': 'credential-id',
        'type': 'public-key',
        'transports': ['internal'],
      },
    ]);
  });

  test(
    'registration verification handles lifecycle and helper results',
    () async {
      when(
        () => repository.findLatestChallenge(
          userId: 'user-id',
          purpose: 'register',
        ),
      ).thenAnswer((_) async => null);
      expect(
        await service.verifyRegistration(userId: 'user-id', response: const {}),
        isFalse,
      );
      final expired = WebAuthnChallengeRecord(
        id: 'expired',
        challenge: 'old',
        rpId: challenge.rpId,
        origin: challenge.origin,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      when(
        () => repository.findLatestChallenge(
          userId: 'user-id',
          purpose: 'register',
        ),
      ).thenAnswer((_) async => expired);
      expect(
        await service.verifyRegistration(userId: 'user-id', response: const {}),
        isFalse,
      );

      when(
        () => repository.findLatestChallenge(
          userId: 'user-id',
          purpose: 'register',
        ),
      ).thenAnswer((_) async => challenge);
      when(
        () => helper.execute('webauthn-verify-registration.mjs', any()),
      ).thenAnswer(
        (_) async => {
          'verified': false,
          'errorCode': 'origin_mismatch',
          'errorMessage': 'rejected',
        },
      );
      expect(
        await service.verifyRegistration(
          userId: 'user-id',
          response: const {'rawId': 'credential-id'},
        ),
        isFalse,
      );

      when(
        () => helper.execute('webauthn-verify-registration.mjs', any()),
      ).thenAnswer(
        (_) async => {
          'verified': true,
          'registrationInfo': {
            'credentialID': 'credential-id',
            'credentialPublicKey': 'public-key',
            'counter': '8',
            'transports': ['internal'],
            'deviceType': 'singleDevice',
            'backedUp': true,
          },
        },
      );
      when(
        () => repository.insertCredential(
          userId: any(named: 'userId'),
          credentialId: any(named: 'credentialId'),
          publicKey: any(named: 'publicKey'),
          counter: any(named: 'counter'),
          transports: any(named: 'transports'),
          deviceType: any(named: 'deviceType'),
          backedUp: any(named: 'backedUp'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.deleteChallenge(challenge.id),
      ).thenAnswer((_) async {});
      expect(
        await service.verifyRegistration(
          userId: 'user-id',
          response: const {'id': 'credential-id'},
        ),
        isTrue,
      );
    },
  );

  test(
    'authentication options support scoped and discoverable flows',
    () async {
      when(
        () => repository.listCredentialsForUser('empty'),
      ).thenAnswer((_) async => []);
      expect(
        await service.generateAuthenticationOptions(
          userId: 'empty',
          origin: challenge.origin,
        ),
        isNull,
      );
      when(
        () => repository.listCredentialsForUser('user-id'),
      ).thenAnswer((_) async => [credential]);
      when(
        () => helper.execute('webauthn-auth-options.mjs', any()),
      ).thenAnswer((_) async => {'challenge': 'auth-challenge'});
      when(
        () => repository.storeChallenge(
          userId: any(named: 'userId'),
          email: any(named: 'email'),
          purpose: any(named: 'purpose'),
          challenge: 'auth-challenge',
          rpId: 'passport.example.invalid',
          origin: challenge.origin,
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenAnswer((_) async {});
      expect(
        await service.generateAuthenticationOptions(
          userId: 'user-id',
          email: 'user@example.invalid',
          origin: challenge.origin,
          requireUserVerification: true,
        ),
        {'challenge': 'auth-challenge'},
      );
      expect(
        await service.generateAuthenticationOptions(origin: challenge.origin),
        {'challenge': 'auth-challenge'},
      );
    },
  );

  test(
    'authentication verification rejects invalid state and persists success',
    () async {
      expect(await service.verifyAuthentication(response: const {}), isFalse);
      when(
        () => repository.findCredential('missing'),
      ).thenAnswer((_) async => null);
      expect(
        await service.verifyAuthentication(response: const {'id': 'missing'}),
        isFalse,
      );
      when(
        () => repository.findCredential('credential-id'),
      ).thenAnswer((_) async => credential);
      when(
        () => repository.findLatestChallenge(
          userId: null,
          email: null,
          purpose: 'authenticate_discoverable',
        ),
      ).thenAnswer((_) async => null);
      expect(
        await service.verifyAuthentication(
          response: const {'id': 'credential-id'},
        ),
        isFalse,
      );

      when(
        () => repository.findLatestChallenge(
          userId: 'user-id',
          email: 'user@example.invalid',
          purpose: 'authenticate',
        ),
      ).thenAnswer((_) async => challenge);
      when(
        () => helper.execute('webauthn-verify-authentication.mjs', any()),
      ).thenAnswer(
        (_) async => {'verified': false, 'errorCode': 'bad_signature'},
      );
      expect(
        await service.verifyAuthentication(
          userId: 'user-id',
          email: 'user@example.invalid',
          response: const {'id': 'credential-id', 'response': {}},
          forceUserVerification: true,
        ),
        isFalse,
      );

      when(
        () => helper.execute('webauthn-verify-authentication.mjs', any()),
      ).thenAnswer(
        (_) async => {
          'verified': true,
          'authenticationInfo': {'newCounter': '9', 'userVerified': true},
        },
      );
      when(
        () => repository.updateCredentialCounter(
          credentialId: 'credential-id',
          counter: 9,
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.markUserVerified('credential-id'),
      ).thenAnswer((_) async {});
      when(
        () => repository.deleteChallenge(challenge.id),
      ).thenAnswer((_) async {});
      expect(
        await service.verifyAuthentication(
          userId: 'user-id',
          email: 'user@example.invalid',
          response: const {'id': 'credential-id'},
        ),
        isTrue,
      );
    },
  );
}
