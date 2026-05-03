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
  final secret = body['secret']?.toString() ?? '';
  final code = body['code']?.toString() ?? '';
  if (currentPassword.trim().isEmpty ||
      secret.trim().isEmpty ||
      code.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      'current_password, secret and code are required.',
    );
  }

  final user = context.read<AuthenticatedUser>();
  final result = await context.read<AuthService>().verifyAuthenticatorSetup(
        userId: user.id,
        currentPassword: currentPassword,
        secret: secret,
        code: code,
      );

  if (!result.ok) {
    return errorResponse(
      result.code ?? 'invalid_request',
      result.message ?? 'Request failed.',
      statusCode: result.statusCode,
    );
  }

  return jsonResponse({'updated': true});
}
