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

  final newPassword = body['new_password']?.toString() ?? '';
  final emailCode = body['email_code']?.toString() ?? '';
  if (newPassword.trim().isEmpty || emailCode.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      'new_password and email_code are required.',
    );
  }

  final user = context.read<AuthenticatedUser>();
  final result = await context.read<AuthService>().resetPasswordWithCode(
        userId: user.id,
        newPassword: newPassword,
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
