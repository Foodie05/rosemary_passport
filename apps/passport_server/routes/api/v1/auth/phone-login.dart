import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/auth_response.dart';
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
  final verifyCode = (body['verify_code'] ?? '').toString().trim();
  if (phoneNumber.isEmpty || verifyCode.isEmpty) {
    return errorResponse('invalid_request', '请输入手机号和验证码。');
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final attempt = await context.read<AuthService>().loginWithPhoneCode(
    phoneNumber: phoneNumber,
    verifyCode: verifyCode,
    requestIp: requestIp,
  );
  if (!attempt.ok) {
    return errorResponse(
      attempt.code ?? 'login_failed',
      attempt.message ?? '登录失败，请稍后重试。',
      statusCode: attempt.statusCode,
    );
  }

  final result = attempt.result!;
  final responseBody = await buildFirstPartyAuthPayload(
    context,
    user: result.user,
    tokens: result.tokens,
  );
  return authJsonResponse(
    context,
    responseBody,
    accessToken: result.tokens.accessToken,
  );
}
