import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/authenticated_user.dart';
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

  final phoneNumber = (body['phone_number'] ?? '').toString();
  final currentPassword = (body['current_password'] ?? '').toString();
  final captchaToken = (body['captcha_token'] ?? '').toString();
  if (phoneNumber.trim().isEmpty || currentPassword.trim().isEmpty) {
    return errorResponse('invalid_request', '请输入手机号和当前密码。');
  }

  final user = context.read<AuthenticatedUser>();
  final authService = context.read<AuthService>();
  final bypassCaptcha = await authService.shouldBypassBootstrapCaptchaForUser(user.id);
  if (!bypassCaptcha && captchaToken.trim().isEmpty) {
    return errorResponse('invalid_request', '请先完成人机验证。');
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  if (!bypassCaptcha) {
    final captchaOk = await authService.verifyCaptcha(captchaToken.trim(), ip: requestIp);
    if (!captchaOk) {
      return errorResponse('captcha_failed', '人机验证未通过，请重试。', statusCode: 400);
    }
  }

  final result = await authService.sendBindPhoneCode(
    userId: user.id,
    phoneNumber: phoneNumber,
    currentPassword: currentPassword,
    requestIp: requestIp,
  );
  if (!result.ok) {
    return errorResponse(
      result.code ?? 'invalid_request',
      result.message ?? '请求失败，请稍后重试。',
      statusCode: result.statusCode,
    );
  }
  return jsonResponse({'sent': true});
}
