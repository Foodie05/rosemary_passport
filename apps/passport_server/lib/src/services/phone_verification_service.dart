import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../repositories/settings_repository.dart';
import 'security_policy_service.dart';
import 'security_service.dart';

class PhoneVerificationAttempt {
  const PhoneVerificationAttempt.success({required this.retryAfterSeconds})
    : ok = true,
      code = null,
      message = null,
      statusCode = 200;

  const PhoneVerificationAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       retryAfterSeconds = null;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final int? retryAfterSeconds;
}

class PhoneVerifyCheckAttempt {
  const PhoneVerifyCheckAttempt.success()
    : ok = true,
      code = null,
      message = null,
      statusCode = 200;

  const PhoneVerifyCheckAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
}

class PhoneVerificationService {
  PhoneVerificationService({
    required AppConfig config,
    SettingsRepository? settingsRepository,
    SecurityService? securityService,
    SecurityPolicyService? securityPolicyService,
  }) : _config = config,
       _settingsRepository = settingsRepository,
       _security = securityService,
       _policy = securityPolicyService;

  final AppConfig _config;
  final SettingsRepository? _settingsRepository;
  final SecurityService? _security;
  final SecurityPolicyService? _policy;
  final _uuid = const Uuid();

  static const _sendPhoneScope = 'verification-code:phone:send:phone';
  static const _sendIpScope = 'verification-code:phone:send:ip';
  static const _sendCooldownScope =
      'verification-code:phone:send:cooldown:phone';
  static const _verifyPhoneScope = 'verification-code:phone:verify:phone';
  static const _verifyIpScope = 'verification-code:phone:verify:ip';

  Future<Map<String, String>> _resolveProviderSettings() async {
    final fromDb = await _settingsRepository?.getJson('security') ??
        const <String, dynamic>{};
    String readDb(String key, String fallback) {
      final value = (fromDb[key] ?? '').toString().trim();
      return value.isNotEmpty ? value : fallback;
    }
    return {
      'accessKeyId': readDb('phone_sms_access_key_id', _config.aliyunAccessKeyId),
      'accessKeySecret': readDb(
        'phone_sms_access_key_secret',
        _config.aliyunAccessKeySecret,
      ),
      'signName': readDb('phone_sms_sign_name', _config.aliyunSmsSignName),
      'templateCode': readDb(
        'phone_sms_template_code',
        _config.aliyunSmsTemplateCode,
      ),
      'schemeName': readDb('phone_sms_scheme_name', _config.aliyunSmsSchemeName),
      'countryCode': readDb('phone_sms_country_code', _config.aliyunSmsCountryCode),
    };
  }

  Future<PhoneVerificationAttempt> sendCode({
    required String phoneNumber,
    required String requestIp,
    String countryCode = '86',
  }) async {
    final provider = await _resolveProviderSettings();
    if (provider['accessKeyId']!.isEmpty ||
        provider['accessKeySecret']!.isEmpty ||
        provider['signName']!.isEmpty ||
        provider['templateCode']!.isEmpty) {
      return const PhoneVerificationAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }

    if (countryCode != '86') {
      return const PhoneVerificationAttempt.failure(
        code: 'unsupported_country_code',
        message: '当前仅支持中国大陆手机号。',
      );
    }

    final normalizedPhone = normalizePhone(
      phoneNumber,
      countryCode: countryCode,
    );
    if (normalizedPhone == null) {
      return const PhoneVerificationAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }

    final policy = await _loadPolicy();
    final cooldown = await _security?.retryAfterSeconds(
      scope: _sendCooldownScope,
      subject: normalizedPhone,
    );
    if ((cooldown ?? 0) > 0) {
      return PhoneVerificationAttempt.failure(
        code: 'rate_limited',
        message: '请求过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }

    final phoneThrottle = await _security?.enforce(
      scope: _sendPhoneScope,
      subject: normalizedPhone,
      limit: policy.registerCodeEmailLimit,
      window: Duration(seconds: policy.registerCodeWindowSeconds),
      blockDuration: Duration(seconds: policy.registerCodeBlockSeconds),
    );
    if (phoneThrottle != null && !phoneThrottle.allowed) {
      return const PhoneVerificationAttempt.failure(
        code: 'rate_limited',
        message: '请求过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }

    final ipThrottle = await _security?.enforce(
      scope: _sendIpScope,
      subject: requestIp,
      limit: policy.registerCodeIpLimit,
      window: Duration(seconds: policy.registerCodeWindowSeconds),
      blockDuration: Duration(seconds: policy.registerCodeBlockSeconds),
    );
    if (ipThrottle != null && !ipThrottle.allowed) {
      return const PhoneVerificationAttempt.failure(
        code: 'rate_limited',
        message: '请求过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }

    final helperResponse = await _runHelper('sms-send-verify-code.mjs', {
      'accessKeyId': provider['accessKeyId'],
      'accessKeySecret': provider['accessKeySecret'],
      'countryCode': provider['countryCode'] ?? countryCode,
      'phoneNumber': normalizedPhone,
      'signName': provider['signName'],
      'templateCode': provider['templateCode'],
      'templateParam': jsonEncode({
        'code': '##code##',
        'min': (_config.aliyunSmsCodeValidTimeSeconds ~/ 60).toString(),
      }),
      'codeLength': _config.aliyunSmsCodeLength,
      'validTime': _config.aliyunSmsCodeValidTimeSeconds,
      'interval': _config.aliyunSmsSendIntervalSeconds,
      'duplicatePolicy': _config.aliyunSmsDuplicatePolicy,
      'outId': _uuid.v4(),
      if ((provider['schemeName'] ?? '').isNotEmpty)
        'schemeName': provider['schemeName'],
    });

    final success = helperResponse['success'] == true;
    final responseCode = '${helperResponse['code'] ?? ''}';
    if (!success || responseCode != 'OK') {
      if (responseCode == 'FREQUENCY_FAIL') {
        return const PhoneVerificationAttempt.failure(
          code: 'rate_limited',
          message: '请求过于频繁，请稍后再试。',
          statusCode: 429,
        );
      }
      return const PhoneVerificationAttempt.failure(
        code: 'temporary_issue',
        message: '验证码发送失败，请稍后重试。',
        statusCode: 503,
      );
    }

    final cooldownSeconds = policy.registerCodeCooldownSeconds;
    await _security?.startCooldown(
      scope: _sendCooldownScope,
      subject: normalizedPhone,
      duration: Duration(seconds: cooldownSeconds),
    );

    return PhoneVerificationAttempt.success(retryAfterSeconds: cooldownSeconds);
  }

  Future<PhoneVerifyCheckAttempt> verifyCode({
    required String phoneNumber,
    required String verifyCode,
    required String requestIp,
    String countryCode = '86',
  }) async {
    final provider = await _resolveProviderSettings();
    if (provider['accessKeyId']!.isEmpty ||
        provider['accessKeySecret']!.isEmpty ||
        provider['signName']!.isEmpty ||
        provider['templateCode']!.isEmpty) {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'phone_verification_not_configured',
        message: '手机号验证码服务尚未配置。',
        statusCode: 503,
      );
    }
    if (countryCode != '86') {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'unsupported_country_code',
        message: '当前仅支持中国大陆手机号。',
      );
    }

    final normalizedPhone = normalizePhone(
      phoneNumber,
      countryCode: countryCode,
    );
    if (normalizedPhone == null) {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'invalid_phone_number',
        message: '手机号格式不正确。',
      );
    }
    final trimmedCode = verifyCode.trim();
    if (!RegExp(r'^[0-9A-Za-z]{4,8}$').hasMatch(trimmedCode)) {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'invalid_verify_code',
        message: '验证码格式不正确。',
      );
    }

    final policy = await _loadPolicy();
    final phoneThrottle = await _security?.enforce(
      scope: _verifyPhoneScope,
      subject: normalizedPhone,
      limit: policy.emailCodeMaxAttempts,
      window: const Duration(minutes: 10),
      blockDuration: const Duration(minutes: 10),
    );
    if (phoneThrottle != null && !phoneThrottle.allowed) {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'rate_limited',
        message: '验证尝试过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }
    final ipThrottle = await _security?.enforce(
      scope: _verifyIpScope,
      subject: requestIp,
      limit: policy.loginIpLimit,
      window: Duration(seconds: policy.loginWindowSeconds),
      blockDuration: Duration(seconds: policy.loginBlockSeconds),
    );
    if (ipThrottle != null && !ipThrottle.allowed) {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'rate_limited',
        message: '验证尝试过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }

    late final Map<String, dynamic> helperResponse;
    try {
      helperResponse = await _runHelper('sms-check-verify-code.mjs', {
        'accessKeyId': provider['accessKeyId'],
        'accessKeySecret': provider['accessKeySecret'],
        'countryCode': provider['countryCode'] ?? countryCode,
        'phoneNumber': normalizedPhone,
        'verifyCode': trimmedCode,
        if (_config.aliyunSmsSchemeName.isNotEmpty)
          'schemeName': _config.aliyunSmsSchemeName,
      });
    } on StateError catch (error) {
      if (_isInvalidVerifyCodeProviderError(error.message)) {
        return const PhoneVerifyCheckAttempt.failure(
          code: 'invalid_verify_code',
          message: '验证码错误或已失效。',
          statusCode: 400,
        );
      }
      rethrow;
    }
    final success = helperResponse['success'] == true;
    final responseCode = '${helperResponse['code'] ?? ''}';
    final responseMessage = '${helperResponse['message'] ?? ''}';
    final verifyResult = '${helperResponse['verifyResult'] ?? ''}'
        .toUpperCase();
    if (_isInvalidVerifyCodeProviderError('$responseCode $responseMessage')) {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'invalid_verify_code',
        message: '验证码错误或已失效。',
        statusCode: 400,
      );
    }
    if (!success || responseCode != 'OK') {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'temporary_issue',
        message: '验证码校验失败，请稍后重试。',
        statusCode: 503,
      );
    }
    if (verifyResult != 'PASS') {
      return const PhoneVerifyCheckAttempt.failure(
        code: 'invalid_verify_code',
        message: '验证码错误或已失效。',
        statusCode: 400,
      );
    }

    await _security?.clear(scope: _verifyPhoneScope, subject: normalizedPhone);
    await _security?.clear(scope: _verifyIpScope, subject: requestIp);
    return const PhoneVerifyCheckAttempt.success();
  }

  bool _isInvalidVerifyCodeProviderError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('validatefail') ||
        normalized.contains('验证失败') ||
        normalized.contains('invalid verify') ||
        normalized.contains('invalid code');
  }

  String? normalizePhone(String raw, {String countryCode = '86'}) {
    if (countryCode != '86') {
      return null;
    }
    var phone = raw.trim();
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('+86')) {
      phone = phone.substring(3);
    } else if (phone.startsWith('86') && phone.length == 13) {
      phone = phone.substring(2);
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      return null;
    }
    return phone;
  }

  Future<Map<String, dynamic>> _runHelper(
    String scriptName,
    Map<String, dynamic> payload,
  ) async {
    final process = await Process.start('node', [
      'scripts/$scriptName',
    ], workingDirectory: Directory.current.path);
    process.stdin.writeln(jsonEncode(payload));
    await process.stdin.close();

    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw StateError('Phone helper failed: $stderr');
    }
    return Map<String, dynamic>.from(jsonDecode(stdout) as Map);
  }

  Future<SecurityPolicy> _loadPolicy() async {
    final service = _policy;
    if (service == null) {
      return SecurityPolicyService.defaultPolicy;
    }
    return service.load();
  }
}
