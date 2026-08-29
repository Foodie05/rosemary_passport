import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/auth_cookie.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }
  final config = context.read<AppConfig>();
  if (!hasTrustedBrowserOrigin(context.request, config)) {
    return errorResponse(
      'invalid_origin',
      'Request origin is not allowed.',
      statusCode: 403,
    );
  }

  final accessToken = readCookieValue(
    context.request.headers['cookie'],
    kAccessTokenCookieName,
  );
  await context.read<AuthService>().logoutFirstPartySession(
    accessToken: accessToken,
    refreshToken: readRefreshTokenCookie(
      context.request.headers['cookie'],
      config,
    ),
    requestIp: clientIpFromRequest(context.request, config: config),
  );

  return jsonResponse(
    {'ok': true},
    headers: {
      'set-cookie': <String>[
        buildExpiredAccessTokenCookie(config: config),
        buildExpiredRefreshTokenCookie(config: config),
      ],
    },
  );
}
