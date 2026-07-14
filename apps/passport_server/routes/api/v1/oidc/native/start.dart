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

  return jsonResponse({
    ...description.toJson(),
    'issuer': serverBaseUrl(context),
  });
}
