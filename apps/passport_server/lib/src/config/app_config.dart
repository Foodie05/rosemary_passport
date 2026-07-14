import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';

class AppConfig {
  AppConfig._(this._env);

  factory AppConfig.fromEnv() {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final config = AppConfig._(env);
    config._validateCriticalSecrets();
    return config;
  }

  final DotEnv _env;

  String get serverBaseUrl =>
      _env['SERVER_BASE_URL'] ?? 'https://passport.local';
  String get webBaseUrl {
    final explicit = (_env['WEB_BASE_URL'] ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    if (_isLocalDevelopmentHost) {
      return 'http://localhost:5173';
    }
    try {
      return Uri.parse(serverBaseUrl).origin;
    } catch (_) {
      return 'http://localhost:5173';
    }
  }

  String get dbHost => _env['DB_HOST'] ?? '127.0.0.1';
  int get dbPort => int.parse(_env['DB_PORT'] ?? '5432');
  String get dbUser => _env['DB_USER'] ?? 'rosm_passport';
  String get dbPassword => _env['DB_PASSWORD'] ?? '';
  String get dbName => _env['DB_NAME'] ?? 'rosm_passport';
  String get dbSslMode => (_env['DB_SSL_MODE'] ?? 'require').toLowerCase();

  String get jwtIssuer => _env['JWT_ISSUER'] ?? 'rosm-passport';
  String get jwtAudience => _env['JWT_AUDIENCE'] ?? 'rosm-apps';
  String get jwtPrivateKeyPem =>
      _pemFromEnv('JWT_PRIVATE_KEY_PEM_B64', 'JWT_PRIVATE_KEY_PEM');
  String get jwtPublicKeyPem =>
      _pemFromEnv('JWT_PUBLIC_KEY_PEM_B64', 'JWT_PUBLIC_KEY_PEM');
  String get jwtBindingKey => _env['JWT_BINDING_KEY'] ?? '';
  String get emailCodeHmacKey {
    final explicit = (_env['EMAIL_CODE_HMAC_KEY'] ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return jwtBindingKey;
  }

  String get dataEncryptionKey {
    final explicit = (_env['DATA_ENCRYPTION_KEY'] ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return jwtBindingKey;
  }

  int get accessTokenTtlSeconds =>
      int.parse(_env['ACCESS_TOKEN_TTL_SECONDS'] ?? '900');
  int get refreshTokenTtlSeconds =>
      int.parse(_env['REFRESH_TOKEN_TTL_SECONDS'] ?? '2592000');

  int get argon2MemoryKb => int.parse(_env['ARGON2_MEMORY_KB'] ?? '65536');
  int get argon2Iterations => int.parse(_env['ARGON2_ITERATIONS'] ?? '4');
  int get argon2Parallelism => int.parse(_env['ARGON2_PARALLELISM'] ?? '1');

  String get hcaptchaSecret => _env['HCAPTCHA_SECRET'] ?? '';
  String get hcaptchaSiteKey => _env['HCAPTCHA_SITEKEY'] ?? '';
  String get captchaSecret {
    if (hcaptchaSecret.isNotEmpty) {
      return hcaptchaSecret;
    }
    // Backward compatibility for legacy env key.
    return _env['TURNSTILE_SECRET'] ?? '';
  }

  String get smtpHost => _env['SMTP_HOST'] ?? '';
  int get smtpPort => int.parse(_env['SMTP_PORT'] ?? '587');
  String get smtpUser => _env['SMTP_USER'] ?? '';
  String get smtpPassword => _env['SMTP_PASSWORD'] ?? '';
  String get smtpFrom =>
      _env['SMTP_FROM'] ?? 'ROSM Passport <no-reply@localhost>';
  bool get smtpSecure =>
      (_env['SMTP_SECURE'] ?? 'false').toLowerCase() == 'true';
  int get emailCodeTtlSeconds =>
      int.parse(_env['EMAIL_CODE_TTL_SECONDS'] ?? '300');

  String get aliyunAccessKeyId => (_env['ALIYUN_ACCESS_KEY_ID'] ?? '').trim();
  String get aliyunAccessKeySecret =>
      (_env['ALIYUN_ACCESS_KEY_SECRET'] ?? '').trim();
  String get aliyunSmsSignName => (_env['ALIYUN_SMS_SIGN_NAME'] ?? '').trim();
  String get aliyunSmsTemplateCode =>
      (_env['ALIYUN_SMS_TEMPLATE_CODE'] ?? '').trim();
  String get aliyunSmsSchemeName =>
      (_env['ALIYUN_SMS_SCHEME_NAME'] ?? '').trim();
  String get aliyunSmsCountryCode =>
      (_env['ALIYUN_SMS_COUNTRY_CODE'] ?? '86').trim();
  int get aliyunSmsCodeLength =>
      int.parse(_env['ALIYUN_SMS_CODE_LENGTH'] ?? '6');
  int get aliyunSmsCodeValidTimeSeconds =>
      int.parse(_env['ALIYUN_SMS_VALID_TIME_SECONDS'] ?? '300');
  int get aliyunSmsSendIntervalSeconds =>
      int.parse(_env['ALIYUN_SMS_SEND_INTERVAL_SECONDS'] ?? '60');
  int get aliyunSmsDuplicatePolicy =>
      int.parse(_env['ALIYUN_SMS_DUPLICATE_POLICY'] ?? '1');
  bool get phoneVerificationEnabled =>
      aliyunAccessKeyId.isNotEmpty &&
      aliyunAccessKeySecret.isNotEmpty &&
      aliyunSmsSignName.isNotEmpty &&
      aliyunSmsTemplateCode.isNotEmpty;

  bool get oidcRequirePkce =>
      (_env['OIDC_REQUIRE_PKCE'] ?? 'true').toLowerCase() == 'true';
  bool get trustProxyHeaders =>
      (_env['TRUST_PROXY_HEADERS'] ?? 'false').toLowerCase() == 'true';
  List<String> get trustedProxyIps => (_env['TRUSTED_PROXY_IPS'] ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  List<String> get corsAllowedOrigins {
    final configured = (_env['CORS_ALLOWED_ORIGINS'] ?? '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (configured.isNotEmpty) {
      return configured;
    }

    final defaults = <String>{};
    try {
      final serverOrigin = Uri.parse(serverBaseUrl).origin;
      if (serverOrigin.isNotEmpty) {
        defaults.add(serverOrigin);
      }
    } catch (_) {
      // Ignore malformed SERVER_BASE_URL and fall back to local dev defaults.
    }
    try {
      final webOrigin = Uri.parse(webBaseUrl).origin;
      if (webOrigin.isNotEmpty) {
        defaults.add(webOrigin);
      }
    } catch (_) {
      // Ignore malformed WEB_BASE_URL and keep other defaults.
    }
    defaults.addAll(const ['http://localhost:5173', 'http://127.0.0.1:5173']);
    return defaults.toList();
  }

  String _pemFromEnv(String b64Key, String legacyKey) {
    final b64 = _env[b64Key];
    if (b64 != null && b64.isNotEmpty) {
      try {
        return utf8.decode(base64.decode(base64.normalize(b64)));
      } catch (_) {
        // Fall through to legacy key when b64 is malformed.
      }
    }
    return _env[legacyKey] ?? '';
  }

  bool get _isLocalDevelopmentHost {
    try {
      final host = Uri.parse(serverBaseUrl).host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1';
    } catch (_) {
      return false;
    }
  }

  bool isTrustedProxyAddress(String rawAddress) {
    final address = rawAddress.trim();
    if (address.isEmpty) {
      return false;
    }
    final configured = trustedProxyIps;
    if (configured.isNotEmpty) {
      return configured.contains(address);
    }
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null) {
      return false;
    }
    return parsed.isLoopback;
  }

  void _validateCriticalSecrets() {
    final weakSecrets = <String>[];
    if (jwtPrivateKeyPem.trim().isEmpty || jwtPublicKeyPem.trim().isEmpty) {
      weakSecrets.add('JWT key pair');
    }
    if (jwtBindingKey.trim().length < 32) {
      weakSecrets.add('JWT_BINDING_KEY');
    }
    if (dataEncryptionKey.trim().length < 32) {
      weakSecrets.add('DATA_ENCRYPTION_KEY');
    }
    if (emailCodeHmacKey.trim().length < 32) {
      weakSecrets.add('EMAIL_CODE_HMAC_KEY');
    }
    if (weakSecrets.isEmpty || _isLocalDevelopmentHost) {
      return;
    }
    throw StateError(
      'Critical security configuration is missing or weak: ${weakSecrets.join(', ')}',
    );
  }
}
