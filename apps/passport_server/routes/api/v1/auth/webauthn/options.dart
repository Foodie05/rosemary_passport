import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/auth_requests.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
        context.request,
        WebAuthnOptionsRequest.fromJson,
      ) ??
      const WebAuthnOptionsRequest();

  final origin = context.request.headers['origin'] ?? '';
  final options = await context.read<AuthService>().beginWebAuthnAuthentication(
        email: payload.email,
        origin: origin,
      );
  if (options == null) {
    return errorResponse('not_configured', '当前账户未配置通行密钥。', statusCode: 404);
  }

  return jsonResponse(options);
}
