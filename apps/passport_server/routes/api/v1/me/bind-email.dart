import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/models/authenticated_user.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse('invalid_request', 'Request body must be a JSON object.');
  }

  final email = body['email']?.toString() ?? '';
  final currentPassword = body['current_password']?.toString() ?? '';
  final emailCode = body['email_code']?.toString() ?? '';
  if (email.trim().isEmpty ||
      currentPassword.trim().isEmpty ||
      emailCode.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      'email, current_password and email_code are required.',
    );
  }

  final user = context.read<AuthenticatedUser>();
  final result = await context.read<AuthService>().bindEmailWithCode(
        userId: user.id,
        newEmail: email,
        currentPassword: currentPassword,
        emailCode: emailCode,
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
