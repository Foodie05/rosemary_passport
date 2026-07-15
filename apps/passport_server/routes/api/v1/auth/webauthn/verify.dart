import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/config/app_config.dart';
import '../../../../../lib/src/models/auth_requests.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/utils/auth_response.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
    context.request,
    WebAuthnVerifyRequest.fromJson,
  );
  if (payload == null) {
    return errorResponse('invalid_request', 'response is required.');
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final attempt = await context.read<AuthService>().loginWithWebAuthn(
    email: payload.email,
    response: payload.response,
    requestIp: requestIp,
  );
  if (!attempt.ok) {
    return errorResponse(
      attempt.code ?? 'login_failed',
      attempt.message ?? '通行密钥登录失败。',
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
