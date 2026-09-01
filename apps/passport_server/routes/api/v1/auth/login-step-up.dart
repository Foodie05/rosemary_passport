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
  final challenge = (body?['step_up_challenge'] ?? '').toString().trim();
  final factor = (body?['factor'] ?? '').toString().trim();
  if (challenge.isEmpty || factor.isEmpty) {
    return errorResponse('invalid_request', '缺少登录验证参数。');
  }
  final proof = <String, dynamic>{
    'password': body?['password'],
    'code': body?['code'],
    if (body?['response'] is Map)
      'response': Map<String, dynamic>.from(body!['response'] as Map),
  };
  final attempt = await context.read<AuthService>().completeLoginStepUp(
    challenge: challenge,
    factor: factor,
    proof: proof,
    rememberMe: body?['remember_me'] == true,
    requestIp: clientIpFromRequest(
      context.request,
      config: context.read<AppConfig>(),
    ),
  );
  if (!attempt.ok) {
    return errorResponse(
      attempt.code ?? 'login_failed',
      attempt.message ?? '登录失败。',
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
    accessTokenMaxAgeSeconds: result.tokens.expiresIn,
    refreshToken: result.tokens.refreshToken,
    refreshTokenMaxAgeSeconds: result.tokens.refreshExpiresIn,
  );
}
