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
    EmailLoginRequest.fromJson,
  );
  if (payload == null ||
      payload.email.trim().isEmpty ||
      payload.emailCode.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      '请输入邮箱和邮箱验证码。',
    );
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final attempt = await context.read<AuthService>().loginWithEmailCode(
    email: payload.email,
    emailCode: payload.emailCode,
    requestIp: requestIp,
  );
  if (!attempt.ok) {
    var response = errorResponse(
      attempt.code ?? 'login_failed',
      attempt.message ?? '登录失败，请稍后重试。',
      statusCode: attempt.statusCode,
    );
    if (attempt.statusCode == 429) {
      final retryAfter = await context.read<AuthService>().loginRetryAfter(
        email: payload.email,
        requestIp: requestIp,
      );
      response = response.copyWith(
        headers: {'retry-after': '${retryAfter ?? 60}'},
      );
    }
    return response;
  }

  final result = attempt.result!;
  final responseBody = await buildFirstPartyAuthPayload(
    context,
    user: result.user,
  );
  return authJsonResponse(
    context,
    responseBody,
    accessToken: result.tokens.accessToken,
  );
}
