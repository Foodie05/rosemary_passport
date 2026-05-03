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
    final captchaSecret = (security['hcaptcha_secret'] ?? '').toString();
    return {
      'smtp': {
        ...smtp,
        'password': '',
        'password_configured': smtpPassword.trim().isNotEmpty,
      },
      'security': {
        ...security,
        'hcaptcha_secret': '',
        'hcaptcha_secret_configured': captchaSecret.trim().isNotEmpty,
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
        'scopes_supported': ['openid', 'profile', 'email'],
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
      if ((nextSecurity['hcaptcha_secret'] ?? '').toString().isEmpty &&
          (current['hcaptcha_secret'] ?? '').toString().isNotEmpty) {
        nextSecurity.remove('hcaptcha_secret');
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

  Future<Map<String, dynamic>> testHcaptchaConnection() async {
    final security = await _settingsRepository.getJson('security');
    final siteKey = (security['hcaptcha_site_key'] ?? '').toString().trim();
    if (siteKey.isEmpty) {
      return {'ok': false, 'message': 'hCaptcha Site Key 未配置。'};
    }
    return _captchaService.verifyCaptchaConfiguration();
  }
}
