import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/services/auth_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null || body['response'] is! Map) {
    return errorResponse('invalid_request', 'response is required.');
  }

  final user = context.read<AuthenticatedUser>();
  final verified = await context.read<AuthService>().verifyWebAuthnRegistration(
        userId: user.id,
        response: Map<String, dynamic>.from(body['response'] as Map),
      );

  if (!verified) {
    return errorResponse('verification_failed', '通行密钥注册失败。', statusCode: 401);
  }

  return jsonResponse({'updated': true});
}
