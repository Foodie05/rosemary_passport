import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/admin_settings_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }

  final settings = await context
      .read<AdminSettingsService>()
      .getSystemSettings();
  final security = settings['security'] is Map<String, dynamic>
      ? Map<String, dynamic>.from(settings['security'] as Map<String, dynamic>)
      : <String, dynamic>{};

  final appConfig = context.read<AppConfig>();
  final siteKey =
      (security['hcaptcha_site_key'] ?? '').toString().trim().isNotEmpty
      ? security['hcaptcha_site_key'].toString().trim()
      : appConfig.hcaptchaSiteKey;

  return jsonResponse({
    'captcha': {'provider': 'hcaptcha', 'site_key': siteKey},
    'security': {
      'register_code_cooldown_seconds':
          security['register_code_cooldown_seconds'],
    },
    'registration': settings['registration'] ?? <String, dynamic>{},
    'phone_verification': {
      'enabled': (security['phone_verification_enabled'] ?? true) == true,
      'country_code': (security['phone_sms_country_code'] ?? '')
              .toString()
              .trim()
              .isNotEmpty
          ? security['phone_sms_country_code'].toString().trim()
          : appConfig.aliyunSmsCountryCode,
      'cooldown_seconds': security['register_code_cooldown_seconds'],
    },
  });
}
