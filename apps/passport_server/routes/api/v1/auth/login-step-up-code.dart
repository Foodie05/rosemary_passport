import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  final challenge = (body?['step_up_challenge'] ?? '').toString().trim();
  final factor = (body?['factor'] ?? '').toString().trim();
  if (challenge.isEmpty || factor.isEmpty) {
    return errorResponse('invalid_request', '缺少登录验证参数。');
  }
  final result = await context.read<AuthService>().sendLoginStepUpCode(
    challenge: challenge,
    factor: factor,
    requestIp: clientIpFromRequest(
      context.request,
      config: context.read<AppConfig>(),
    ),
  );
  return result.ok
      ? jsonResponse({'sent': true, 'message': result.message ?? '验证码已发送。'})
      : errorResponse(
          result.code ?? 'temporary_issue',
          result.message ?? '验证码发送失败。',
          statusCode: result.statusCode,
        );
}
