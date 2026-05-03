import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/authenticated_user.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/services/email_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse('invalid_request', '请求体必须是 JSON 对象。');
  }

  final email = body['email']?.toString() ?? '';
  final currentPassword = body['current_password']?.toString() ?? '';
  final captchaToken = body['captcha_token']?.toString() ?? '';
  final user = context.read<AuthenticatedUser>();
  final authService = context.read<AuthService>();
  final bypassCaptcha = await authService.shouldBypassBootstrapCaptchaForUser(
    user.id,
  );
  if (email.trim().isEmpty || currentPassword.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      '请输入新邮箱和当前密码。',
    );
  }
  if (!bypassCaptcha && captchaToken.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      '请先完成人机验证。',
    );
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  if (!bypassCaptcha) {
    final captchaOk = await authService.verifyCaptcha(
      captchaToken.trim(),
      ip: requestIp,
    );
    if (!captchaOk) {
      return errorResponse('captcha_failed', '人机验证未通过，请重试。',
          statusCode: 400);
    }
  }

  late final result;
  try {
    result = await authService.sendBindEmailCode(
          userId: user.id,
          newEmail: email,
          currentPassword: currentPassword,
          requestIp: requestIp,
        );
  } on EmailDeliveryException {
    return errorResponse(
      'temporary_issue',
      '邮件发送失败，请检查 SMTP 配置后重试。',
      statusCode: 503,
    );
  } catch (_) {
    return errorResponse(
      'temporary_issue',
      '验证码发送失败，请稍后重试。',
      statusCode: 503,
    );
  }

  if (!result.ok) {
    var response = errorResponse(
      result.code ?? 'invalid_request',
      result.message ?? '请求失败，请稍后重试。',
      statusCode: result.statusCode,
    );
    if (result.statusCode == 429) {
      final retryAfter = await authService.bindEmailCodeRetryAfter(
            email: email,
            requestIp: requestIp,
          );
      response = response.copyWith(
        headers: {'retry-after': '${retryAfter ?? 60}'},
      );
    }
    return response;
  }

  return jsonResponse({
    'sent': true,
    'retry_after': await authService.bindEmailCodeCooldownRetryAfter(
          email: email,
        ),
  });
}
