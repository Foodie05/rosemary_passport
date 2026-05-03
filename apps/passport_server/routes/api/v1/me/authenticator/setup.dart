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
    return errorResponse('invalid_request', 'Request body must be a JSON object.');
  }

  final currentPassword = body['current_password']?.toString() ?? '';
  if (currentPassword.trim().isEmpty) {
    return errorResponse('invalid_request', 'current_password is required.');
  }

  final user = context.read<AuthenticatedUser>();
  final payload = await context.read<AuthService>().beginAuthenticatorSetup(
        userId: user.id,
        currentPassword: currentPassword,
      );

  if (payload == null) {
    return errorResponse('invalid_password', '当前密码错误。', statusCode: 401);
  }

  return jsonResponse(payload);
}
