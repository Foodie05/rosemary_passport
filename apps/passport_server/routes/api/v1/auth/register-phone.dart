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
  final nickname = (body['nickname'] ?? '').toString().trim();
  final password = (body['password'] ?? '').toString();
  if (phoneNumber.isEmpty ||
      verifyCode.isEmpty ||
      nickname.isEmpty ||
      password.isEmpty) {
    return errorResponse(
      'invalid_request',
      'phone_number, verify_code, nickname and password are required.',
    );
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final attempt = await context.read<AuthService>().registerWithPhoneCode(
    phoneNumber: phoneNumber,
    nickname: nickname,
    password: password,
    verifyCode: verifyCode,
    requestIp: requestIp,
  );
  if (!attempt.ok) {
    return errorResponse(
      attempt.code ?? 'register_failed',
      attempt.message ?? '注册失败。',
      statusCode: attempt.statusCode,
    );
  }

  final result = attempt.result!;
  final responseBody = await buildFirstPartyAuthPayload(
    context,
    user: result.user,
    tokens: result.tokens,
    postRegistrationPasskeyBootstrap: result.postRegistrationPasskeyBootstrap,
  );
  return authJsonResponse(
    context,
    responseBody,
    accessToken: result.tokens.accessToken,
    statusCode: 201,
  );
}
