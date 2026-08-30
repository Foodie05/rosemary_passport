import 'dart:convert';
import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:test/test.dart';

void main() {
  test('safe defaults are stable for local development', () {
    final config = AppConfig.forTesting(const {});

    expect(config.serverBaseUrl, 'https://passport.local');
    expect(config.webBaseUrl, 'https://passport.local');
    expect(config.dbHost, '127.0.0.1');
    expect(config.dbPort, 5432);
    expect(config.dbUser, 'rosm_passport');
    expect(config.dbPassword, isEmpty);
    expect(config.dbName, 'rosm_passport');
    expect(config.dbSslMode, 'require');
    expect(config.dbPoolMinConnections, 2);
    expect(config.dbPoolMaxConnections, 20);
    expect(config.dbConnectTimeoutSeconds, 2);
    expect(config.dbAcquireTimeoutSeconds, 2);
    expect(config.dbQueryTimeoutSeconds, 5);
    expect(config.dbLockTimeoutMilliseconds, 1000);
    expect(config.jwtIssuer, 'rosm-passport');
    expect(config.jwtAudience, 'rosm-apps');
    expect(config.jwtActiveKid, 'rosm-signing-v1');
    expect(config.jwtSigningKeysDir, isEmpty);
    expect(config.jwtPrivateKeyPem, isEmpty);
    expect(config.jwtPublicKeyPem, isEmpty);
    expect(config.jwtBindingKey, isEmpty);
    expect(config.emailCodeHmacKey, isEmpty);
    expect(config.dataEncryptionKey, isEmpty);
    expect(config.dataEncryptionActiveKid, 'data-v1');
    expect(config.dataEncryptionKeys, {'data-v1': ''});
    expect(config.accessTokenTtlSeconds, 900);
    expect(config.firstPartyRefreshTokenTtlSeconds, 43200);
    expect(config.firstPartyRememberedRefreshTokenTtlSeconds, 2592000);
    expect(config.refreshTokenTtlSeconds, 2592000);
    expect(config.legacyJsonRefreshSunsetAt, DateTime.utc(2026, 9, 13));
    expect(config.argon2MemoryKb, 65536);
    expect(config.argon2Iterations, 4);
    expect(config.argon2Parallelism, 1);
    expect(config.smtpHost, isEmpty);
    expect(config.smtpPort, 587);
    expect(config.smtpUser, isEmpty);
    expect(config.smtpPassword, isEmpty);
    expect(config.smtpFrom, contains('no-reply@localhost'));
    expect(config.smtpSecure, isFalse);
    expect(config.emailCodeTtlSeconds, 300);
    expect(config.helperTimeoutSeconds, 3);
    expect(config.helperBaseUrl, isEmpty);
    expect(config.helperSharedKey, isEmpty);
    expect(config.aliyunCaptchaRegion, 'cn');
    expect(config.aliyunSmsCountryCode, '86');
    expect(config.aliyunSmsCodeLength, 6);
    expect(config.aliyunSmsCodeValidTimeSeconds, 300);
    expect(config.aliyunSmsSendIntervalSeconds, 60);
    expect(config.aliyunSmsDuplicatePolicy, 1);
    expect(config.phoneVerificationEnabled, isFalse);
    expect(config.oidcRequirePkce, isTrue);
    expect(config.requireFileSecrets, isFalse);
    expect(config.webAuthnAndroidOrigins, isEmpty);
    expect(config.trustProxyHeaders, isFalse);
    expect(config.trustedProxyIps, isEmpty);
    expect(config.jwtPublicKeysPem, {'rosm-signing-v1': ''});
    expect(config.jwtActivePrivateKeyPem, isEmpty);
  });

  test('explicit values, fallbacks, lists, and origins are normalized', () {
    final privatePem = base64.encode(utf8.encode('PRIVATE PEM'));
    final config = AppConfig.forTesting({
      'SERVER_BASE_URL': 'http://localhost:8080',
      'WEB_BASE_URL': ' https://web.example.invalid ',
      'DB_HOST': 'db',
      'DB_PORT': '5544',
      'DB_USER': 'app',
      'DB_PASSWORD': 'database-secret',
      'DB_NAME': 'passport',
      'DB_SSL_MODE': 'VERIFY-FULL',
      'DB_POOL_MIN_CONNECTIONS': '3',
      'DB_POOL_MAX_CONNECTIONS': '18',
      'DB_CONNECT_TIMEOUT_SECONDS': '4',
      'DB_POOL_ACQUIRE_TIMEOUT_SECONDS': '6',
      'DB_QUERY_TIMEOUT_SECONDS': '8',
      'DB_LOCK_TIMEOUT_MILLISECONDS': '1200',
      'JWT_ISSUER': 'issuer',
      'JWT_AUDIENCE': 'audience',
      'JWT_ACTIVE_KID': ' current ',
      'JWT_PRIVATE_KEY_PEM_B64': privatePem,
      'JWT_PUBLIC_KEY_PEM_B64': 'not-base64',
      'JWT_PUBLIC_KEY_PEM': 'PUBLIC PEM',
      'JWT_BINDING_KEY': 'binding-secret',
      'EMAIL_CODE_HMAC_KEY': 'email-secret',
      'DATA_ENCRYPTION_KEY': 'data-secret',
      'DATA_ENCRYPTION_ACTIVE_KID': ' active-data ',
      'FIRST_PARTY_REFRESH_TOKEN_TTL_SECONDS': '100',
      'FIRST_PARTY_REMEMBERED_REFRESH_TOKEN_TTL_SECONDS': '200',
      'REFRESH_TOKEN_TTL_SECONDS': '300',
      'LEGACY_JSON_REFRESH_SUNSET_AT': '2026-09-14T08:00:00+08:00',
      'ARGON2_MEMORY_KB': '32768',
      'ARGON2_ITERATIONS': '3',
      'ARGON2_PARALLELISM': '2',
      'ALIYUN_CAPTCHA_PREFIX': ' captcha-prefix ',
      'ALIYUN_CAPTCHA_SCENE_ID': ' scene ',
      'ALIYUN_ACCESS_KEY_ID': ' fallback-id ',
      'ALIYUN_ACCESS_KEY_SECRET': ' fallback-secret ',
      'ALIYUN_SMS_SIGN_NAME': ' sign ',
      'ALIYUN_SMS_TEMPLATE_CODE': ' template ',
      'ALIYUN_SMS_SCHEME_NAME': ' scheme ',
      'ALIYUN_SMS_COUNTRY_CODE': '1',
      'ALIYUN_SMS_CODE_LENGTH': '8',
      'ALIYUN_SMS_VALID_TIME_SECONDS': '600',
      'ALIYUN_SMS_SEND_INTERVAL_SECONDS': '90',
      'ALIYUN_SMS_DUPLICATE_POLICY': '2',
      'SMTP_HOST': 'smtp.example.invalid',
      'SMTP_PORT': '465',
      'SMTP_USER': 'mailer',
      'SMTP_PASSWORD': 'smtp-secret',
      'SMTP_FROM': 'Passport <passport@example.invalid>',
      'SMTP_SECURE': 'TRUE',
      'EMAIL_CODE_TTL_SECONDS': '420',
      'HELPER_TIMEOUT_SECONDS': '7',
      'HELPER_BASE_URL': ' http://helper:3000 ',
      'HELPER_SHARED_KEY': 'helper-secret',
      'OIDC_REQUIRE_PKCE': 'false',
      'REQUIRE_FILE_SECRETS': 'true',
      'WEBAUTHN_ANDROID_ORIGINS': 'android:apk-key-hash:a, , android:b',
      'TRUST_PROXY_HEADERS': 'true',
      'TRUSTED_PROXY_IPS': '10.0.0.1, , 10.0.0.2',
      'CORS_ALLOWED_ORIGINS':
          'https://one.example.invalid, https://one.example.invalid, https://two.example.invalid',
    });

    expect(config.webBaseUrl, 'https://web.example.invalid');
    expect(config.dbHost, 'db');
    expect(config.dbPort, 5544);
    expect(config.dbUser, 'app');
    expect(config.dbPassword, 'database-secret');
    expect(config.dbName, 'passport');
    expect(config.dbSslMode, 'verify-full');
    expect(config.dbPoolMinConnections, 3);
    expect(config.dbPoolMaxConnections, 18);
    expect(config.dbConnectTimeoutSeconds, 4);
    expect(config.dbAcquireTimeoutSeconds, 6);
    expect(config.dbQueryTimeoutSeconds, 8);
    expect(config.dbLockTimeoutMilliseconds, 1200);
    expect(config.jwtIssuer, 'issuer');
    expect(config.jwtAudience, 'audience');
    expect(config.jwtActiveKid, 'current');
    expect(config.jwtPrivateKeyPem, 'PRIVATE PEM');
    expect(config.jwtPublicKeyPem, 'PUBLIC PEM');
    expect(config.emailCodeHmacKey, 'email-secret');
    expect(config.dataEncryptionKey, 'data-secret');
    expect(config.dataEncryptionActiveKid, 'active-data');
    expect(config.firstPartyRefreshTokenTtlSeconds, 100);
    expect(config.firstPartyRememberedRefreshTokenTtlSeconds, 200);
    expect(config.refreshTokenTtlSeconds, 300);
    expect(config.legacyJsonRefreshSunsetAt, DateTime.utc(2026, 9, 14));
    expect(
      config.allowsLegacyJsonRefresh(now: DateTime.utc(2026, 9, 14)),
      isFalse,
    );
    expect(config.argon2MemoryKb, 32768);
    expect(config.argon2Iterations, 3);
    expect(config.argon2Parallelism, 2);
    expect(config.aliyunCaptchaPrefix, 'captcha-prefix');
    expect(config.aliyunCaptchaSceneId, 'scene');
    expect(config.aliyunCaptchaAccessKeyId, 'fallback-id');
    expect(config.aliyunCaptchaAccessKeySecret, 'fallback-secret');
    expect(config.aliyunSmsSignName, 'sign');
    expect(config.aliyunSmsTemplateCode, 'template');
    expect(config.aliyunSmsSchemeName, 'scheme');
    expect(config.aliyunSmsCountryCode, '1');
    expect(config.aliyunSmsCodeLength, 8);
    expect(config.aliyunSmsCodeValidTimeSeconds, 600);
    expect(config.aliyunSmsSendIntervalSeconds, 90);
    expect(config.aliyunSmsDuplicatePolicy, 2);
    expect(config.phoneVerificationEnabled, isTrue);
    expect(config.smtpHost, 'smtp.example.invalid');
    expect(config.smtpPort, 465);
    expect(config.smtpUser, 'mailer');
    expect(config.smtpPassword, 'smtp-secret');
    expect(config.smtpFrom, 'Passport <passport@example.invalid>');
    expect(config.smtpSecure, isTrue);
    expect(config.emailCodeTtlSeconds, 420);
    expect(config.helperTimeoutSeconds, 7);
    expect(config.helperBaseUrl, 'http://helper:3000');
    expect(config.helperSharedKey, 'helper-secret');
    expect(config.oidcRequirePkce, isFalse);
    expect(config.requireFileSecrets, isTrue);
    expect(config.webAuthnAndroidOrigins, [
      'android:apk-key-hash:a',
      'android:b',
    ]);
    expect(config.trustProxyHeaders, isTrue);
    expect(config.trustedProxyIps, ['10.0.0.1', '10.0.0.2']);
    expect(config.corsAllowedOrigins, [
      'https://one.example.invalid',
      'https://two.example.invalid',
    ]);
  });

  test('file secrets and versioned key directories fail closed', () async {
    final directory = await Directory.systemTemp.createTemp('config-keys-');
    addTearDown(() => directory.delete(recursive: true));
    final secret = File('${directory.path}/db-password')
      ..writeAsStringSync(' file-secret\n');
    File('${directory.path}/active.key').writeAsStringSync('active-key\n');
    File('${directory.path}/old.key').writeAsStringSync('old-key\n');
    File('${directory.path}/ignored.txt').writeAsStringSync('ignored');
    File('${directory.path}/signing.public.pem').writeAsStringSync('PUBLIC');
    File('${directory.path}/signing.private.pem').writeAsStringSync('PRIVATE');

    final config = AppConfig.forTesting({
      'DB_PASSWORD_FILE': secret.path,
      'DATA_ENCRYPTION_ACTIVE_KID': 'active',
      'DATA_ENCRYPTION_KEYS_DIR': directory.path,
      'JWT_ACTIVE_KID': 'signing',
      'JWT_SIGNING_KEYS_DIR': directory.path,
    });
    expect(config.dbPassword, 'file-secret');
    expect(config.dataEncryptionKeys, {
      'active': 'active-key',
      'old': 'old-key',
    });
    expect(config.jwtPublicKeysPem, {'signing': 'PUBLIC'});
    expect(config.jwtActivePrivateKeyPem, 'PRIVATE');

    final missing = AppConfig.forTesting({
      'DB_PASSWORD_FILE': '${directory.path}/missing',
      'DATA_ENCRYPTION_ACTIVE_KID': 'missing',
      'DATA_ENCRYPTION_KEYS_DIR': directory.path,
      'JWT_ACTIVE_KID': 'missing',
      'JWT_SIGNING_KEYS_DIR': directory.path,
    });
    expect(() => missing.dbPassword, throwsStateError);
    expect(() => missing.dataEncryptionKeys, throwsStateError);
    expect(() => missing.jwtPublicKeysPem, throwsStateError);
    expect(() => missing.jwtActivePrivateKeyPem, throwsStateError);

    final nonexistent = AppConfig.forTesting({
      'DATA_ENCRYPTION_KEYS_DIR': '${directory.path}/not-a-directory',
      'JWT_SIGNING_KEYS_DIR': '${directory.path}/not-a-directory',
    });
    expect(() => nonexistent.dataEncryptionKeys, throwsStateError);
    expect(() => nonexistent.jwtPublicKeysPem, throwsStateError);
  });

  test('origin and trusted proxy defaults reject malformed input', () {
    final local = AppConfig.forTesting(const {
      'SERVER_BASE_URL': 'http://127.0.0.1:8080',
    });
    expect(local.webBaseUrl, 'http://localhost:5173');
    expect(local.isTrustedProxyAddress('127.0.0.1'), isTrue);
    expect(local.isTrustedProxyAddress('::1'), isTrue);
    expect(local.isTrustedProxyAddress('203.0.113.10'), isFalse);
    expect(local.isTrustedProxyAddress('not-an-ip'), isFalse);
    expect(local.isTrustedProxyAddress('  '), isFalse);

    final explicit = AppConfig.forTesting(const {
      'TRUSTED_PROXY_IPS': '203.0.113.10',
    });
    expect(explicit.isTrustedProxyAddress('203.0.113.10'), isTrue);
    expect(explicit.isTrustedProxyAddress('127.0.0.1'), isFalse);

    final malformed = AppConfig.forTesting(const {
      'SERVER_BASE_URL': ':// malformed',
    });
    expect(malformed.webBaseUrl, 'http://localhost:5173');
    expect(malformed.corsAllowedOrigins, contains('http://localhost:5173'));
  });

  test('legacy JSON refresh compatibility has a fixed cutoff', () {
    final config = AppConfig.forTesting(const {
      'LEGACY_JSON_REFRESH_SUNSET_AT': '2026-09-13T00:00:00Z',
    });
    expect(
      config.allowsLegacyJsonRefresh(
        now: DateTime.utc(2026, 9, 12, 23, 59, 59),
      ),
      isTrue,
    );
    expect(
      config.allowsLegacyJsonRefresh(now: DateTime.utc(2026, 9, 13)),
      isFalse,
    );

    final malformed = AppConfig.forTesting(const {
      'LEGACY_JSON_REFRESH_SUNSET_AT': '2026-09-13 00:00:00',
    });
    expect(() => malformed.legacyJsonRefreshSunsetAt, throwsFormatException);
  });
}
