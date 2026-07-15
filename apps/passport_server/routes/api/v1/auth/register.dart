import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/auth_requests.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/auth_response.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
    context.request,
    RegisterRequest.fromJson,
  );
  if (payload == null ||
      payload.email.trim().isEmpty ||
      payload.nickname.trim().isEmpty ||
      payload.password.isEmpty ||
      payload.emailCode.trim().isEmpty) {
    return errorResponse('invalid_request', '请输入邮箱、昵称、密码和邮箱验证码。');
  }

  final result = await context.read<AuthService>().register(
    email: payload.email,
    nickname: payload.nickname,
    password: payload.password,
    emailCode: payload.emailCode,
    requestIp: clientIpFromRequest(
      context.request,
      config: context.read<AppConfig>(),
    ),
  );

  if (!result.ok || result.result == null) {
    return errorResponse(
      result.code ?? 'register_failed',
      result.message ?? '注册失败，请稍后重试。',
      statusCode: result.statusCode,
    );
  }

  final authResult = result.result!;
  final responseBody = await buildFirstPartyAuthPayload(
    context,
    user: authResult.user,
    tokens: authResult.tokens,
    postRegistrationPasskeyBootstrap:
        authResult.postRegistrationPasskeyBootstrap,
  );
  return authJsonResponse(
    context,
    responseBody,
    statusCode: 201,
    accessToken: authResult.tokens.accessToken,
  );
}
