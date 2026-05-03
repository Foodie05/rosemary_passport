import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../repositories/settings_repository.dart';

class CaptchaService {
  CaptchaService(this._config, [this._settingsRepository]);

  final AppConfig _config;
  final SettingsRepository? _settingsRepository;

  Future<bool> verifyCaptchaToken(String token, {String? remoteIp}) async {
    final result = await verifyCaptchaConfiguration(remoteIp: remoteIp, token: token);
    return result['ok'] == true;
  }

  Future<Map<String, dynamic>> verifyCaptchaConfiguration({
    String? remoteIp,
    String token = 'config-check',
  }) async {
    final secret = await _resolveSecret();
    if (secret.isEmpty) {
      return {
        'ok': false,
        'message': 'hCaptcha Secret 未配置。',
      };
    }

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('https://hcaptcha.com/siteverify'),
        headers: const {'content-type': 'application/x-www-form-urlencoded'},
        body: {
          'secret': secret,
          'response': token,
          if (remoteIp != null) 'remoteip': remoteIp,
        },
      );
    } catch (_) {
      return {
        'ok': false,
        'message': '无法连接到 hCaptcha 校验服务，请检查服务器网络。',
      };
    }

    if (response.statusCode != 200) {
      return {
        'ok': false,
        'message': 'hCaptcha 校验服务返回异常状态，请稍后重试。',
      };
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = (body['error-codes'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    if (body['success'] == true) {
      return {'ok': true, 'message': 'hCaptcha 校验成功。'};
    }
    if (errors.contains('invalid-input-secret') ||
        errors.contains('missing-input-secret')) {
      return {
        'ok': false,
        'message': 'hCaptcha Secret 无效，请检查配置。',
      };
    }
    if (errors.contains('invalid-input-response') ||
        errors.contains('missing-input-response')) {
      return {
        'ok': true,
        'message': 'hCaptcha Secret 可用，站点验证服务连通正常。',
      };
    }
    return {
      'ok': false,
      'message': errors.isEmpty
          ? 'hCaptcha 校验失败，请检查配置。'
          : 'hCaptcha 校验失败：${errors.join(', ')}',
    };
  }

  Future<String> _resolveSecret() async {
    final settingsRepository = _settingsRepository;
    if (settingsRepository != null) {
      final security = await settingsRepository.getJson('security');
      final configured = (security['hcaptcha_secret'] ?? '').toString().trim();
      if (configured.isNotEmpty) {
        return configured;
      }
    }
    return _config.captchaSecret;
  }
}
