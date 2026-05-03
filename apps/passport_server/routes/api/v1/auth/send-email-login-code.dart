import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/auth_requests.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/services/email_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
    context.request,
    EmailRequest.fromJson,
  );
  if (payload == null ||
      payload.email.trim().isEmpty ||
      (payload.captchaToken?.trim().isEmpty ?? true)) {
    return errorResponse(
      'invalid_request',
      '请输入邮箱并完成人机验证。',
    );
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final captchaOk = await context.read<AuthService>().verifyCaptcha(
        payload.captchaToken!.trim(),
        ip: requestIp,
      );
  if (!captchaOk) {
    return errorResponse('captcha_failed', '人机验证未通过，请重试。',
        statusCode: 400);
  }
  try {
    final result = await context.read<AuthService>().sendEmailLoginCode(
          email: payload.email,
          requestIp: requestIp,
        );
    if (!result.ok) {
      var response = errorResponse(
        result.code ?? 'temporary_issue',
        result.message ?? '服务暂时不可用，请稍后重试。',
        statusCode: result.statusCode,
      );
      if (result.statusCode == 429) {
        final retryAfter = await context.read<AuthService>().loginCodeSendRetryAfter(
              email: payload.email,
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
      'message': result.message ?? '验证码已发送。',
      'retry_after': await context.read<AuthService>().loginCodeCooldownRetryAfter(
            email: payload.email,
          ),
    });
  } on EmailDeliveryException {
    return errorResponse('temporary_issue', '邮件发送失败，请稍后重试。', statusCode: 503);
  } catch (_) {
    return errorResponse('temporary_issue', '邮件发送失败，请稍后重试。', statusCode: 503);
  }
}
