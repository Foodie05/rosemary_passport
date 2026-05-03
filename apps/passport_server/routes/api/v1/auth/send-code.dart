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
    SendRegisterCodeRequest.fromJson,
  );
  if (payload == null ||
      payload.email.trim().isEmpty ||
      payload.captchaToken.trim().isEmpty) {
    return errorResponse(
        'invalid_request', '请输入邮箱并完成人机验证。');
  }

  final authService = context.read<AuthService>();
  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final captchaOk = await authService.verifyCaptcha(
    payload.captchaToken,
    ip: requestIp,
  );
  if (!captchaOk) {
    return errorResponse('captcha_failed', '人机验证未通过，请重试。',
        statusCode: 400);
  }

  try {
    final result = await authService.sendRegisterCode(
      email: payload.email,
      requestIp: requestIp,
    );
    if (!result.ok) {
      var response = errorResponse(
        result.code ?? 'temporary_issue',
        result.message ?? '出现临时问题',
        statusCode: result.statusCode,
      );
      if (result.statusCode == 429) {
        final retryAfter = await authService.registerCodeRetryAfter(
          email: payload.email,
          requestIp: requestIp,
        );
        response = response.copyWith(
          headers: {'retry-after': '${retryAfter ?? 60}'},
        );
      }
      return response;
    }
  } on EmailDeliveryException {
    return errorResponse(
      'temporary_issue',
      '出现临时问题',
      statusCode: 503,
    );
  } catch (_) {
    return errorResponse(
      'temporary_issue',
      '出现临时问题',
      statusCode: 503,
    );
  }
  return jsonResponse({
    'sent': true,
    'retry_after': await authService.loginCodeCooldownRetryAfter(
      email: payload.email,
    ),
  });
}
