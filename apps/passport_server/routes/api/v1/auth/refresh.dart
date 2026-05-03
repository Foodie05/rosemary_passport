import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/auth_requests.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/auth_cookie.dart';
import '../../../../lib/src/utils/auth_response.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
    context.request,
    RefreshRequest.fromJson,
  );
  final refreshToken =
      payload?.refreshToken.trim() ??
      readCookieValue(
        context.request.headers['cookie'],
        'rosm_refresh_token',
      ) ??
      '';
  if (refreshToken.isEmpty) {
    return errorResponse('invalid_request', 'refresh_token is required.');
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  final pair = await context.read<AuthService>().refreshForClient(
    refreshToken,
    clientId: 'first_party_web',
    requestIp: requestIp,
  );
  if (pair == null) {
    final retryAfter = await context.read<AuthService>().refreshRetryAfter(
      requestIp: requestIp,
    );
    var response = errorResponse(
      'invalid_grant',
      'Refresh token invalid.',
      statusCode: retryAfter == null ? 401 : 429,
    );
    if (retryAfter != null) {
      response = response.copyWith(headers: {'retry-after': '$retryAfter'});
    }
    return response;
  }

  return authJsonResponse(context, const {
    'refreshed': true,
  }, accessToken: pair.accessToken);
}
