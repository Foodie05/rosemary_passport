import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/middleware/guards.dart';
import '../../../../../lib/src/services/oidc_service.dart';
import '../../../../../lib/src/utils/http.dart';
import '../../../../../lib/src/utils/native_oidc.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  final request = parseNativeAuthorizationRequest(body);
  if (request == null) {
    return invalidNativeAuthorizationResponse();
  }

  final user = await currentUser(context);
  if (user == null) {
    return errorResponse(
      'unauthorized',
      'Access token is missing or invalid.',
      statusCode: 401,
    );
  }

  final description = await describeNativeAuthorization(context, request);
  if (description == null) {
    return invalidNativeAuthorizationResponse();
  }

  final code = await context.read<OidcService>().authorize(
    clientId: request.clientId,
    redirectUri: request.redirectUri,
    responseType: request.responseType,
    scope: request.scope,
    user: user,
    nonce: request.nonce,
    codeChallenge: request.codeChallenge,
    codeChallengeMethod: request.codeChallengeMethod,
  );
  if (code == null) {
    return invalidNativeAuthorizationResponse();
  }

  final callback = callbackUriFor(
    redirectUri: request.redirectUri,
    code: code,
    state: request.state,
  );

  return jsonResponse({
    'code': code,
    if (request.state != null) 'state': request.state,
    'redirect_uri': request.redirectUri,
    'callback_url': callback.toString(),
    'client': description.toJson()['client'],
  });
}
