import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse('invalid_request', '请求体必须是 JSON 对象。');
  }
  final phoneNumber = (body['phone_number'] ?? '').toString().trim();
  final captchaToken = (body['captcha_token'] ?? '').toString().trim();
  if (phoneNumber.isEmpty || captchaToken.isEmpty) {
    return errorResponse('invalid_request', '请输入手机号并完成人机验证。');
  }

  final authService = context.read<AuthService>();
  final requestIp = clientIpFromRequest(context.request, config: context.read<AppConfig>());
  final captchaOk = await authService.verifyCaptcha(captchaToken, ip: requestIp);
  if (!captchaOk) {
    return errorResponse('captcha_failed', '人机验证未通过，请重试。', statusCode: 400);
  }

  final result = await authService.sendPhoneRegisterCode(
    phoneNumber: phoneNumber,
    requestIp: requestIp,
  );
  if (!result.ok) {
    return errorResponse(result.code ?? 'temporary_issue', result.message ?? '发送失败。', statusCode: result.statusCode);
  }
  return jsonResponse({'sent': true, 'message': result.message ?? '验证码已发送。'});
}
