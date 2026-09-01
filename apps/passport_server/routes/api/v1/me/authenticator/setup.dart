import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse(
      'invalid_request',
      'Request body must be a JSON object.',
    );
  }

  final currentPassword = body['current_password']?.toString() ?? '';

  final user = context.read<AuthenticatedUser>();
  final payload = await context.read<AuthService>().beginAuthenticatorSetup(
    userId: user.id,
    currentPassword: currentPassword,
    stepUpVerified: true,
  );

  if (payload == null)
    return errorResponse('temporary_issue', '暂时无法初始化验证器。', statusCode: 503);

  return jsonResponse(payload);
}
