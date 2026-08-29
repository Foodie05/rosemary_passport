import 'dart:io';

import '../config/app_config.dart';
import '../repositories/settings_repository.dart';
import 'captcha_service.dart';
import 'security_policy_service.dart';

class AdminSettingsService {
  AdminSettingsService(
    this._settingsRepository,
    this._config,
    this._captchaService, [
    SecurityPolicyService? securityPolicyService,
  ]) : _securityPolicyService = securityPolicyService;

  final SettingsRepository _settingsRepository;
  final AppConfig _config;
  final CaptchaService _captchaService;
  SecurityPolicyService? _securityPolicyService;

  SecurityPolicyService get _policyService =>
      _securityPolicyService ??= SecurityPolicyService(_settingsRepository);

  Future<Map<String, dynamic>> getSystemSettings() async {
    final smtp = await _settingsRepository.getJson('smtp');
    final security = await _policyService.mergedSecuritySettings();
    final registration = await _settingsRepository.getJson('registration');
    final smtpPassword = (smtp['password'] ?? '').toString();
    final captchaAccessKeySecret =
        (security['aliyun_captcha_access_key_secret'] ?? '').toString();
    final captchaAccessKeyId = (security['aliyun_captcha_access_key_id'] ?? '')
        .toString();
    return {
      'smtp': {
        ...smtp,
        'password': '',
        'password_configured': smtpPassword.trim().isNotEmpty,
      },
      'security': {
        ...security,
        'aliyun_captcha_access_key_id': '',
        'aliyun_captcha_access_key_id_configured': captchaAccessKeyId
            .trim()
            .isNotEmpty,
        'aliyun_captcha_access_key_secret': '',
        'aliyun_captcha_access_key_secret_configured': captchaAccessKeySecret
            .trim()
            .isNotEmpty,
        'phone_verification_enabled':
            (security['phone_verification_enabled'] ?? true) == true,
        'phone_sms_access_key_id': '',
        'phone_sms_access_key_id_configured':
            (security['phone_sms_access_key_id'] ?? '')
                .toString()
                .trim()
                .isNotEmpty,
        'phone_sms_access_key_secret': '',
        'phone_sms_access_key_secret_configured':
            (security['phone_sms_access_key_secret'] ?? '')
                .toString()
                .trim()
                .isNotEmpty,
        'phone_sms_sign_name': (security['phone_sms_sign_name'] ?? '')
            .toString(),
        'phone_sms_template_code': (security['phone_sms_template_code'] ?? '')
            .toString(),
        'phone_sms_scheme_name': (security['phone_sms_scheme_name'] ?? '')
            .toString(),
      },
      'registration': registration,
      'oidc': {
        'issuer': _config.serverBaseUrl,
        'authorization_endpoint': '${_config.serverBaseUrl}/oidc/authorize',
        'token_endpoint': '${_config.serverBaseUrl}/oidc/token',
        'userinfo_endpoint': '${_config.serverBaseUrl}/oidc/userinfo',
        'jwks_uri': '${_config.serverBaseUrl}/oidc/jwks',
        'introspection_endpoint': '${_config.serverBaseUrl}/oidc/introspect',
        'revocation_endpoint': '${_config.serverBaseUrl}/oidc/revoke',
        'jwt_issuer': _config.jwtIssuer,
        'jwt_audience': _config.jwtAudience,
        'access_token_ttl_seconds': _config.accessTokenTtlSeconds,
        'refresh_token_ttl_seconds': _config.refreshTokenTtlSeconds,
        'pkce_required': _config.oidcRequirePkce,
        'response_types_supported': ['code'],
        'grant_types_supported': ['authorization_code', 'refresh_token'],
        'scopes_supported': [
          'openid',
          'profile',
          'email',
          'phone',
          'accountRule',
        ],
        'token_endpoint_auth_methods_supported': ['client_secret_post', 'none'],
        'id_token_signing_alg_values_supported': ['RS256'],
      },
    };
  }

  Future<void> updateSystemSettings(Map<String, dynamic> payload) async {
    if (payload['smtp'] is Map<String, dynamic>) {
      final current = await _settingsRepository.getJson('smtp');
      final nextSmtp = Map<String, dynamic>.from(
        payload['smtp'] as Map<String, dynamic>,
      );
      if ((nextSmtp['password'] ?? '').toString().isEmpty &&
          (current['password'] ?? '').toString().isNotEmpty) {
        nextSmtp.remove('password');
      }
      await _settingsRepository.upsertJson('smtp', {...current, ...nextSmtp});
    }
    if (payload['security'] is Map<String, dynamic>) {
      final current = await _settingsRepository.getJson('security');
      final nextSecurity = Map<String, dynamic>.from(
        payload['security'] as Map<String, dynamic>,
      );
      final submittedSceneId = nextSecurity['aliyun_captcha_scene_id'];
      if (submittedSceneId != null) {
        final sceneId = submittedSceneId.toString().trim();
        if (sceneId.isNotEmpty && !RegExp(r'^[a-z0-9]+$').hasMatch(sceneId)) {
          throw const FormatException(
            '场景 ID 只能填写验证码 2.0 控制台显示的小写字母和数字，不要包含场景名称。',
          );
        }
        nextSecurity['aliyun_captcha_scene_id'] = sceneId;
      }
      if ((nextSecurity['aliyun_captcha_access_key_secret'] ?? '')
              .toString()
              .isEmpty &&
          (current['aliyun_captcha_access_key_secret'] ?? '')
              .toString()
              .isNotEmpty) {
        nextSecurity.remove('aliyun_captcha_access_key_secret');
      }
      if ((nextSecurity['aliyun_captcha_access_key_id'] ?? '')
              .toString()
              .isEmpty &&
          (current['aliyun_captcha_access_key_id'] ?? '')
              .toString()
              .isNotEmpty) {
        nextSecurity.remove('aliyun_captcha_access_key_id');
      }
      if ((nextSecurity['phone_sms_access_key_secret'] ?? '')
              .toString()
              .isEmpty &&
          (current['phone_sms_access_key_secret'] ?? '')
              .toString()
              .isNotEmpty) {
        nextSecurity.remove('phone_sms_access_key_secret');
      }
      if ((nextSecurity['phone_sms_access_key_id'] ?? '').toString().isEmpty &&
          (current['phone_sms_access_key_id'] ?? '').toString().isNotEmpty) {
        nextSecurity.remove('phone_sms_access_key_id');
      }
      final next = _policyService.sanitizeSecuritySettings({
        ...current,
        ...nextSecurity,
      });
      await _settingsRepository.upsertJson('security', next);
    }
    if (payload['registration'] is Map<String, dynamic>) {
      final current = await _settingsRepository.getJson('registration');
      await _settingsRepository.upsertJson('registration', {
        ...current,
        ...Map<String, dynamic>.from(
          payload['registration'] as Map<String, dynamic>,
        ),
      });
    }
  }

  Future<List<Map<String, dynamic>>> listTemplates() {
    return _settingsRepository.listEmailTemplates();
  }

  Future<Map<String, dynamic>?> getTemplate(String name) {
    return _settingsRepository.getEmailTemplate(name);
  }

  Future<void> upsertTemplate({
    required String name,
    required String subject,
    required String html,
    required String text,
  }) {
    return _settingsRepository.upsertEmailTemplate(
      name: name,
      subject: subject,
      html: html,
      text: text,
    );
  }

  Future<Map<String, dynamic>> testSmtpConnection() async {
    final smtp = await _settingsRepository.getJson('smtp');
    final host = (smtp['host'] ?? '').toString();
    final portRaw = smtp['port'];
    final port = portRaw is int ? portRaw : int.tryParse('$portRaw');
    if (host.isEmpty || port == null) {
      return {'ok': false, 'message': 'SMTP host/port 未配置完整。'};
    }

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      await socket.close();
      return {'ok': true, 'message': 'TCP 连接成功，SMTP服务可达。'};
    } catch (_) {
      return {'ok': false, 'message': '连接失败，请检查 SMTP 主机、端口和网络策略。'};
    }
  }

  Future<Map<String, dynamic>> testAliyunCaptchaConnection(String token) async {
    final security = await _settingsRepository.getJson('security');
    String configured(String key, String fallback) {
      final value = (security[key] ?? '').toString().trim();
      return value.isNotEmpty ? value : fallback;
    }

    final prefix = configured(
      'aliyun_captcha_prefix',
      _config.aliyunCaptchaPrefix,
    );
    final sceneId = configured(
      'aliyun_captcha_scene_id',
      _config.aliyunCaptchaSceneId,
    );
    final accessKeyId = configured(
      'aliyun_captcha_access_key_id',
      configured('phone_sms_access_key_id', _config.aliyunCaptchaAccessKeyId),
    );
    final accessKeySecret = configured(
      'aliyun_captcha_access_key_secret',
      configured(
        'phone_sms_access_key_secret',
        _config.aliyunCaptchaAccessKeySecret,
      ),
    );
    if (prefix.isEmpty ||
        sceneId.isEmpty ||
        accessKeyId.isEmpty ||
        accessKeySecret.isEmpty) {
      return {'ok': false, 'message': '请先完整配置阿里云验证码 Prefix、场景 ID 和 AccessKey。'};
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(sceneId)) {
      return {
        'ok': false,
        'message': '场景 ID 只能填写验证码 2.0 控制台显示的小写字母和数字，不要包含场景名称。',
      };
    }
    return _captchaService.verifyCaptchaConfiguration(token: token);
  }

  Future<Map<String, dynamic>> testPhoneSmsConfig() async {
    final security = await _settingsRepository.getJson('security');
    final enabled = (security['phone_verification_enabled'] ?? true) == true;
    if (!enabled) {
      return {'ok': false, 'message': '手机号验证码功能已关闭。'};
    }
    final accessKeyId = (security['phone_sms_access_key_id'] ?? '')
        .toString()
        .trim();
    final accessKeySecret = (security['phone_sms_access_key_secret'] ?? '')
        .toString()
        .trim();
    final signName = (security['phone_sms_sign_name'] ?? '').toString().trim();
    final templateCode = (security['phone_sms_template_code'] ?? '')
        .toString()
        .trim();
    if (accessKeyId.isEmpty ||
        accessKeySecret.isEmpty ||
        signName.isEmpty ||
        templateCode.isEmpty) {
      return {'ok': false, 'message': '请先完整配置短信 AccessKey、签名和模板。'};
    }
    return {'ok': true, 'message': '短信配置字段完整，可用于手机号验证。'};
  }
}
