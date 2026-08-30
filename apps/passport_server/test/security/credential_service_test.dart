import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:rosm_passport_server/src/services/auth_attempts.dart';
import 'package:rosm_passport_server/src/services/authenticator_service.dart';
import 'package:rosm_passport_server/src/services/credential_service.dart';
import 'package:rosm_passport_server/src/services/webauthn_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockAudit extends Mock implements AuditService {}

class _MockAuthenticator extends Mock implements AuthenticatorService {}

class _MockWebAuthn extends Mock implements WebAuthnService {}

void main() {
  const user = UserRecord(
    id: 'user-id',
    email: 'user@example.invalid',
    phoneNumber: '+8613800000000',
    nickname: 'User',
    passwordHash: 'password-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: true,
  );
  const admin = UserRecord(
    id: 'admin-id',
    email: 'admin@example.invalid',
    phoneNumber: null,
    nickname: 'Admin',
    passwordHash: 'admin-password-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: 'encrypted-secret',
    hasAuthenticator: true,
    roles: ['admin'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );

  late _MockUsers users;
  late _MockPasswords passwords;
  late _MockAudit audit;
  late _MockAuthenticator authenticator;
  late _MockWebAuthn webAuthn;
  late CredentialService service;

  setUp(() {
    users = _MockUsers();
    passwords = _MockPasswords();
    audit = _MockAudit();
    authenticator = _MockAuthenticator();
    webAuthn = _MockWebAuthn();
    service = CredentialService(
      userRepository: users,
      passwordHasher: passwords,
      auditService: audit,
      authenticatorService: authenticator,
      webAuthnService: webAuthn,
    );
  });

  test('security code validation preserves the existing credential', () async {
    when(() => users.findById(any())).thenAnswer((_) async => null);
    expect(
      (await service.updateSecurityCode(
        userId: 'missing',
        currentPassword: 'password',
        securityCode: '123456',
      )).code,
      'not_found',
    );

    when(() => users.findById(any())).thenAnswer((_) async => user);
    expect(
      (await service.updateSecurityCode(
        userId: user.id,
        currentPassword: '',
        securityCode: '123456',
      )).code,
      'invalid_request',
    );
    expect(
      (await service.updateSecurityCode(
        userId: user.id,
        currentPassword: 'password',
        securityCode: '12345x',
      )).code,
      'invalid_security_code',
    );

    when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
    expect(
      (await service.updateSecurityCode(
        userId: user.id,
        currentPassword: 'wrong',
        securityCode: '123456',
      )).code,
      'invalid_password',
    );

    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(() => passwords.hash(any())).thenAnswer((_) async => 'new-code-hash');
    when(
      () => users.updateSecurityCodeHash(
        userId: any(named: 'userId'),
        securityCodeHash: any(named: 'securityCodeHash'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => audit.log(
        action: any(named: 'action'),
        actorId: any(named: 'actorId'),
        actorType: any(named: 'actorType'),
        resourceType: any(named: 'resourceType'),
        resourceId: any(named: 'resourceId'),
        metadata: any(named: 'metadata'),
        ip: any(named: 'ip'),
      ),
    ).thenAnswer((_) async {});
    final result = await service.updateSecurityCode(
      userId: user.id,
      currentPassword: 'password',
      securityCode: ' 123456 ',
    );
    expect(result.ok, isTrue);
    verify(
      () => users.updateSecurityCodeHash(
        userId: user.id,
        securityCodeHash: 'new-code-hash',
      ),
    ).called(1);
  });

  test('authenticator setup requires password and a valid TOTP', () async {
    when(() => users.findById(any())).thenAnswer((_) async => null);
    expect(
      await service.beginAuthenticatorSetup(
        userId: 'missing',
        currentPassword: 'password',
      ),
      isNull,
    );

    when(() => users.findById(any())).thenAnswer((_) async => user);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
    expect(
      await service.beginAuthenticatorSetup(
        userId: user.id,
        currentPassword: 'wrong',
      ),
      isNull,
    );

    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(authenticator.generateSecret).thenReturn('SECRET');
    when(
      () => authenticator.buildOtpAuthUri(
        email: any(named: 'email'),
        secret: any(named: 'secret'),
      ),
    ).thenReturn('otpauth://test');
    expect(
      await service.beginAuthenticatorSetup(
        userId: user.id,
        currentPassword: 'password',
      ),
      {'secret': 'SECRET', 'otpauth_uri': 'otpauth://test'},
    );

    when(
      () => authenticator.verifyCode(
        secret: any(named: 'secret'),
        code: any(named: 'code'),
      ),
    ).thenReturn(false);
    expect(
      (await service.verifyAuthenticatorSetup(
        userId: user.id,
        currentPassword: 'password',
        secret: ' SECRET ',
        code: '000000',
      )).code,
      'invalid_totp_code',
    );

    when(
      () => authenticator.verifyCode(
        secret: any(named: 'secret'),
        code: any(named: 'code'),
      ),
    ).thenReturn(true);
    when(
      () => users.updateAuthenticatorSecret(
        userId: any(named: 'userId'),
        authenticatorSecret: any(named: 'authenticatorSecret'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => audit.log(
        action: any(named: 'action'),
        actorId: any(named: 'actorId'),
        actorType: any(named: 'actorType'),
        resourceType: any(named: 'resourceType'),
        resourceId: any(named: 'resourceId'),
        metadata: any(named: 'metadata'),
        ip: any(named: 'ip'),
      ),
    ).thenAnswer((_) async {});
    expect(
      (await service.verifyAuthenticatorSetup(
        userId: user.id,
        currentPassword: 'password',
        secret: ' SECRET ',
        code: '123456',
      )).ok,
      isTrue,
    );
  });

  test(
    'WebAuthn registration enforces availability, step-up, and limit',
    () async {
      when(() => users.findById(any())).thenAnswer((_) async => null);
      expect(
        await service.beginWebAuthnRegistration(
          userId: 'missing',
          origin: 'https://passport.example.invalid',
        ),
        isNull,
      );

      final unavailable = CredentialService(
        userRepository: users,
        passwordHasher: passwords,
        auditService: audit,
      );
      when(() => users.findById(any())).thenAnswer((_) async => user);
      await expectLater(
        unavailable.beginWebAuthnRegistration(
          userId: user.id,
          origin: 'https://passport.example.invalid',
        ),
        throwsA(isA<WebAuthnUnavailableException>()),
      );

      when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
      expect(
        await service.beginWebAuthnRegistration(
          userId: user.id,
          origin: 'https://passport.example.invalid',
          currentPassword: 'wrong',
        ),
        isNull,
      );

      when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
      when(
        () => webAuthn.countCredentials(user.id),
      ).thenAnswer((_) async => CredentialService.maxWebAuthnCredentials);
      await expectLater(
        service.beginWebAuthnRegistration(
          userId: user.id,
          origin: 'https://passport.example.invalid',
          currentPassword: 'password',
        ),
        throwsA(isA<WebAuthnCredentialLimitException>()),
      );

      when(() => webAuthn.countCredentials(user.id)).thenAnswer((_) async => 1);
      when(
        () => webAuthn.generateRegistrationOptions(
          userId: any(named: 'userId'),
          email: any(named: 'email'),
          nickname: any(named: 'nickname'),
          origin: any(named: 'origin'),
        ),
      ).thenAnswer((_) async => {'challenge': 'challenge'});
      expect(
        await service.beginWebAuthnRegistration(
          userId: user.id,
          origin: 'https://passport.example.invalid',
          allowPostRegistrationBootstrap: true,
        ),
        {'challenge': 'challenge'},
      );
    },
  );

  test('WebAuthn management supports disabled and configured modes', () async {
    final disabled = CredentialService(
      userRepository: users,
      passwordHasher: passwords,
      auditService: audit,
    );
    expect(
      await disabled.verifyWebAuthnRegistration(
        userId: user.id,
        response: const {},
      ),
      isFalse,
    );
    expect(await disabled.listWebAuthnCredentials(userId: user.id), isEmpty);
    await disabled.deleteWebAuthnCredential(
      userId: user.id,
      credentialId: 'credential-id',
    );
    expect(
      await disabled.beginWebAuthnAuthentication(
        origin: 'https://passport.example.invalid',
      ),
      isNull,
    );

    when(
      () => webAuthn.verifyRegistration(
        userId: user.id,
        response: any(named: 'response'),
      ),
    ).thenAnswer((_) async => true);
    when(() => webAuthn.listCredentials(user.id)).thenAnswer(
      (_) async => [
        const {'credential_id': 'credential-id'},
      ],
    );
    when(
      () => webAuthn.deleteCredential(
        userId: user.id,
        credentialId: 'credential-id',
      ),
    ).thenAnswer((_) async {});
    when(
      () => audit.log(
        action: any(named: 'action'),
        actorId: any(named: 'actorId'),
        actorType: any(named: 'actorType'),
        resourceType: any(named: 'resourceType'),
        resourceId: any(named: 'resourceId'),
        metadata: any(named: 'metadata'),
        ip: any(named: 'ip'),
      ),
    ).thenAnswer((_) async {});
    expect(
      await service.verifyWebAuthnRegistration(
        userId: user.id,
        response: const {},
      ),
      isTrue,
    );
    expect(
      await service.listWebAuthnCredentials(userId: user.id),
      hasLength(1),
    );
    await service.deleteWebAuthnCredential(
      userId: user.id,
      credentialId: 'credential-id',
    );
    verify(
      () => audit.log(
        action: 'user.webauthn.deleted',
        actorId: user.id,
        actorType: 'user',
        resourceType: 'user_webauthn_credential',
        resourceId: 'credential-id',
        metadata: any(named: 'metadata'),
        ip: any(named: 'ip'),
      ),
    ).called(1);
  });

  test(
    'authentication options and security state do not enumerate users',
    () async {
      when(
        () => webAuthn.generateAuthenticationOptions(
          email: any(named: 'email'),
          origin: any(named: 'origin'),
          userId: any(named: 'userId'),
          requireUserVerification: any(named: 'requireUserVerification'),
        ),
      ).thenAnswer((_) async => {'challenge': 'challenge'});
      expect(
        await service.beginWebAuthnAuthentication(
          origin: 'https://passport.example.invalid',
        ),
        {'challenge': 'challenge'},
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      expect(
        await service.beginWebAuthnAuthentication(
          email: 'missing@example.invalid',
          origin: 'https://passport.example.invalid',
        ),
        isNull,
      );
      when(() => users.findByEmail(any())).thenAnswer((_) async => admin);
      expect(
        await service.beginWebAuthnAuthentication(
          email: admin.email,
          origin: 'https://passport.example.invalid',
        ),
        {'challenge': 'challenge'},
      );
      verify(
        () => webAuthn.generateAuthenticationOptions(
          email: admin.email,
          origin: 'https://passport.example.invalid',
          userId: admin.id,
          requireUserVerification: true,
        ),
      ).called(1);

      when(() => users.findById(any())).thenAnswer((_) async => null);
      expect(await service.getSecurityState(userId: 'missing'), const {
        'has_passkey': false,
        'has_authenticator': false,
        'has_phone': false,
      });
      when(() => users.findById(any())).thenAnswer((_) async => user);
      when(
        () => webAuthn.hasCredentials(user.id),
      ).thenAnswer((_) async => true);
      expect(await service.getSecurityState(userId: user.id), const {
        'has_passkey': true,
        'has_authenticator': false,
        'has_phone': true,
      });
    },
  );
}
