import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/auth_cookie.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final accessToken = readCookieValue(
    context.request.headers['cookie'],
    kAccessTokenCookieName,
  );
  await context.read<AuthService>().logoutFirstPartySession(
    accessToken: accessToken,
  );

  return jsonResponse(
    {'ok': true},
    headers: {
      'set-cookie': buildExpiredAccessTokenCookie(
        config: context.read<AppConfig>(),
      ),
    },
  );
}
