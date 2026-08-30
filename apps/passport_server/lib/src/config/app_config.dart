import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';

class AppConfig {
  AppConfig._(this._env);

  factory AppConfig.fromEnv() {
    // File values are development defaults. Explicit process/container
    // environment values must win so deployment configuration is predictable.
    final env = DotEnv()..load();
    env.addAll(Platform.environment);
    final config = AppConfig._(env);
    config._validateCriticalSecrets();
    return config;
  }

  factory AppConfig.forTesting(Map<String, String> values) {
    final env = DotEnv(quiet: true)..addAll(values);
    return AppConfig._(env);
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
  String get dbPassword => _secret('DB_PASSWORD');
  String get dbName => _env['DB_NAME'] ?? 'rosm_passport';
  String get dbSslMode => (_env['DB_SSL_MODE'] ?? 'require').toLowerCase();
  int get dbPoolMinConnections =>
      int.parse(_env['DB_POOL_MIN_CONNECTIONS'] ?? '2');
  int get dbPoolMaxConnections =>
      int.parse(_env['DB_POOL_MAX_CONNECTIONS'] ?? '20');
  int get dbConnectTimeoutSeconds =>
      int.parse(_env['DB_CONNECT_TIMEOUT_SECONDS'] ?? '2');
  int get dbAcquireTimeoutSeconds =>
      int.parse(_env['DB_POOL_ACQUIRE_TIMEOUT_SECONDS'] ?? '2');
  int get dbQueryTimeoutSeconds =>
      int.parse(_env['DB_QUERY_TIMEOUT_SECONDS'] ?? '5');
  int get dbLockTimeoutMilliseconds =>
      int.parse(_env['DB_LOCK_TIMEOUT_MILLISECONDS'] ?? '1000');

  String get jwtIssuer => _env['JWT_ISSUER'] ?? 'rosm-passport';
  String get jwtAudience => _env['JWT_AUDIENCE'] ?? 'rosm-apps';
  String get jwtActiveKid =>
      (_env['JWT_ACTIVE_KID'] ?? 'rosm-signing-v1').trim();
  String get jwtSigningKeysDir => (_env['JWT_SIGNING_KEYS_DIR'] ?? '').trim();
  String get jwtPrivateKeyPem =>
      _pemFromEnv('JWT_PRIVATE_KEY_PEM_B64', 'JWT_PRIVATE_KEY_PEM');
  String get jwtPublicKeyPem =>
      _pemFromEnv('JWT_PUBLIC_KEY_PEM_B64', 'JWT_PUBLIC_KEY_PEM');
  String get jwtBindingKey => _secret('JWT_BINDING_KEY');
  String get emailCodeHmacKey {
    final explicit = _secret('EMAIL_CODE_HMAC_KEY').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return jwtBindingKey;
  }

  String get dataEncryptionKey {
    final explicit = _secret('DATA_ENCRYPTION_KEY').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return jwtBindingKey;
  }

  String get dataEncryptionActiveKid =>
      (_env['DATA_ENCRYPTION_ACTIVE_KID'] ?? 'data-v1').trim();
  String get dataEncryptionKeysDir =>
      (_env['DATA_ENCRYPTION_KEYS_DIR'] ?? '').trim();

  Map<String, String> get dataEncryptionKeys {
    final directory = dataEncryptionKeysDir;
    if (directory.isEmpty) {
      return {dataEncryptionActiveKid: dataEncryptionKey};
    }
    final keys = <String, String>{};
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw StateError('DATA_ENCRYPTION_KEYS_DIR does not exist.');
    }
    for (final entry in dir.listSync().whereType<File>()) {
      if (!entry.path.endsWith('.key')) {
        continue;
      }
      final name = entry.uri.pathSegments.last;
      final kid = name.substring(0, name.length - '.key'.length);
      keys[kid] = entry.readAsStringSync().trim();
    }
    if (!keys.containsKey(dataEncryptionActiveKid)) {
      throw StateError('Active data encryption key is missing.');
    }
    return keys;
  }

  int get accessTokenTtlSeconds => 900;
  int get firstPartyRefreshTokenTtlSeconds =>
      int.parse(_env['FIRST_PARTY_REFRESH_TOKEN_TTL_SECONDS'] ?? '43200');
  int get firstPartyRememberedRefreshTokenTtlSeconds => int.parse(
    _env['FIRST_PARTY_REMEMBERED_REFRESH_TOKEN_TTL_SECONDS'] ?? '2592000',
  );
  int get refreshTokenTtlSeconds =>
      int.parse(_env['REFRESH_TOKEN_TTL_SECONDS'] ?? '2592000');
  DateTime get legacyJsonRefreshSunsetAt {
    final raw = (_env['LEGACY_JSON_REFRESH_SUNSET_AT'] ?? '').trim();
    if (raw.isEmpty) {
      return DateTime.utc(2026, 9, 13);
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null ||
        (!raw.endsWith('Z') && !raw.contains(RegExp(r'[+-]\d\d:\d\d$')))) {
      throw const FormatException(
        'LEGACY_JSON_REFRESH_SUNSET_AT must include a UTC offset.',
      );
    }
    return parsed.toUtc();
  }

  bool allowsLegacyJsonRefresh({DateTime? now}) {
    return (now ?? DateTime.now().toUtc()).isBefore(legacyJsonRefreshSunsetAt);
  }

  int get argon2MemoryKb => int.parse(_env['ARGON2_MEMORY_KB'] ?? '65536');
  int get argon2Iterations => int.parse(_env['ARGON2_ITERATIONS'] ?? '4');
  int get argon2Parallelism => int.parse(_env['ARGON2_PARALLELISM'] ?? '1');

  String get aliyunCaptchaPrefix =>
      (_env['ALIYUN_CAPTCHA_PREFIX'] ?? '').trim();
  String get aliyunCaptchaSceneId =>
      (_env['ALIYUN_CAPTCHA_SCENE_ID'] ?? '').trim();
  String get aliyunCaptchaAccessKeyId {
    final dedicated = _secret('ALIYUN_CAPTCHA_ACCESS_KEY_ID').trim();
    return dedicated.isNotEmpty ? dedicated : aliyunAccessKeyId;
  }

  String get aliyunCaptchaAccessKeySecret {
    final dedicated = _secret('ALIYUN_CAPTCHA_ACCESS_KEY_SECRET').trim();
    return dedicated.isNotEmpty ? dedicated : aliyunAccessKeySecret;
  }

  String get aliyunCaptchaRegion => 'cn';

  String get smtpHost => _env['SMTP_HOST'] ?? '';
  int get smtpPort => int.parse(_env['SMTP_PORT'] ?? '587');
  String get smtpUser => _env['SMTP_USER'] ?? '';
  String get smtpPassword => _secret('SMTP_PASSWORD');
  String get smtpFrom =>
      _env['SMTP_FROM'] ?? 'ROSM Passport <no-reply@localhost>';
  bool get smtpSecure =>
      (_env['SMTP_SECURE'] ?? 'false').toLowerCase() == 'true';
  int get emailCodeTtlSeconds =>
      int.parse(_env['EMAIL_CODE_TTL_SECONDS'] ?? '300');
  int get helperTimeoutSeconds =>
      int.parse(_env['HELPER_TIMEOUT_SECONDS'] ?? '3');
  String get helperBaseUrl => (_env['HELPER_BASE_URL'] ?? '').trim();
  String get helperSharedKey => _secret('HELPER_SHARED_KEY');

  String get aliyunAccessKeyId => _secret('ALIYUN_ACCESS_KEY_ID').trim();
  String get aliyunAccessKeySecret =>
      _secret('ALIYUN_ACCESS_KEY_SECRET').trim();
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
  bool get requireFileSecrets =>
      (_env['REQUIRE_FILE_SECRETS'] ?? 'false').toLowerCase() == 'true';
  List<String> get webAuthnAndroidOrigins =>
      _csvList(_env['WEBAUTHN_ANDROID_ORIGINS'] ?? '');
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

  List<String> _csvList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _pemFromEnv(String b64Key, String legacyKey) {
    final b64 = _secret(b64Key);
    if (b64.isNotEmpty) {
      try {
        return utf8.decode(base64.decode(base64.normalize(b64)));
      } catch (_) {
        // Fall through to legacy key when b64 is malformed.
      }
    }
    return _secret(legacyKey);
  }

  Map<String, String> get jwtPublicKeysPem {
    final directory = jwtSigningKeysDir;
    if (directory.isEmpty) {
      return {jwtActiveKid: jwtPublicKeyPem};
    }
    final keys = <String, String>{};
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw StateError('JWT_SIGNING_KEYS_DIR does not exist.');
    }
    for (final entry in dir.listSync().whereType<File>()) {
      if (!entry.path.endsWith('.public.pem')) {
        continue;
      }
      final name = entry.uri.pathSegments.last;
      final kid = name.substring(0, name.length - '.public.pem'.length);
      if (kid.isNotEmpty) {
        keys[kid] = entry.readAsStringSync();
      }
    }
    if (!keys.containsKey(jwtActiveKid)) {
      throw StateError('JWT active public key is missing.');
    }
    return keys;
  }

  String get jwtActivePrivateKeyPem {
    final directory = jwtSigningKeysDir;
    if (directory.isEmpty) {
      return jwtPrivateKeyPem;
    }
    final file = File('$directory/$jwtActiveKid.private.pem');
    if (!file.existsSync()) {
      throw StateError('JWT active private key is missing.');
    }
    return file.readAsStringSync();
  }

  String _secret(String name) {
    final path = (_env['${name}_FILE'] ?? '').trim();
    if (path.isNotEmpty) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('${name}_FILE does not exist.');
      }
      return file.readAsStringSync().trim();
    }
    return _env[name] ?? '';
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
    try {
      if (jwtActivePrivateKeyPem.trim().isEmpty ||
          jwtPublicKeysPem[jwtActiveKid]?.trim().isEmpty != false) {
        weakSecrets.add('JWT key pair');
      }
    } catch (_) {
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
    final configuredAccessTtl = (_env['ACCESS_TOKEN_TTL_SECONDS'] ?? '900')
        .trim();
    if (configuredAccessTtl != '900') {
      weakSecrets.add('ACCESS_TOKEN_TTL_SECONDS must be 900');
    }
    if (!_isLocalDevelopmentHost && !_usesHttps(serverBaseUrl)) {
      weakSecrets.add('SERVER_BASE_URL must use HTTPS');
    }
    if (!_isLocalDevelopmentHost && !_usesHttps(webBaseUrl)) {
      weakSecrets.add('WEB_BASE_URL must use HTTPS');
    }
    if (requireFileSecrets && !_criticalSecretsUseFiles()) {
      weakSecrets.add('production secrets must use *_FILE');
    }
    try {
      legacyJsonRefreshSunsetAt;
      if (requireFileSecrets &&
          (_env['LEGACY_JSON_REFRESH_SUNSET_AT'] ?? '').trim().isEmpty) {
        weakSecrets.add('LEGACY_JSON_REFRESH_SUNSET_AT');
      }
    } catch (_) {
      weakSecrets.add('LEGACY_JSON_REFRESH_SUNSET_AT');
    }
    if (weakSecrets.isEmpty || _isLocalDevelopmentHost) {
      return;
    }
    throw StateError(
      'Critical security configuration is missing or weak: ${weakSecrets.join(', ')}',
    );
  }

  bool _criticalSecretsUseFiles() {
    const required = [
      'DB_PASSWORD',
      'JWT_BINDING_KEY',
      'EMAIL_CODE_HMAC_KEY',
      'DATA_ENCRYPTION_KEY',
    ];
    if (jwtSigningKeysDir.isEmpty) {
      return false;
    }
    final requiredFilesPresent = required.every(
      (name) => (_env['${name}_FILE'] ?? '').trim().isNotEmpty,
    );
    if (!requiredFilesPresent) {
      return false;
    }
    return helperBaseUrl.isEmpty ||
        (_env['HELPER_SHARED_KEY_FILE'] ?? '').trim().isNotEmpty;
  }

  bool _usesHttps(String value) {
    try {
      return Uri.parse(value).scheme.toLowerCase() == 'https';
    } catch (_) {
      return false;
    }
  }
}
