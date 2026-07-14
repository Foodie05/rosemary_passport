import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/utils/http.dart';
import '_native_oidc.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final request = parseNativeAuthorizationRequest(
    await tryParseJsonObject(context.request),
  );
  if (request == null) {
    return invalidNativeAuthorizationResponse();
  }

  final description = await describeNativeAuthorization(context, request);
  if (description == null) {
    return invalidNativeAuthorizationResponse();
  }

  final callback = callbackUriFor(
    redirectUri: request.redirectUri,
    error: 'access_denied',
    errorDescription: 'The user denied the authorization request.',
    state: request.state,
  );

  return jsonResponse({
    'error': 'access_denied',
    'error_description': 'The user denied the authorization request.',
    if (request.state != null) 'state': request.state,
    'redirect_uri': request.redirectUri,
    'callback_url': callback.toString(),
    'client': description.toJson()['client'],
  });
}
