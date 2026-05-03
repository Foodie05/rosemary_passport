import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/models/authenticated_user.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final authService = context.read<AuthService>();
  if (context.request.method == HttpMethod.get) {
    final mustBindEmail = user.roles.contains('admin') &&
        user.email.toLowerCase().trim().endsWith('@rosm.local');
    final securityState = await authService.getSecurityState(userId: user.id);
    return jsonResponse({
      'user': user.toJson(),
      'security': {
        'must_bind_email': mustBindEmail,
        'admin_mfa_required': user.roles.contains('admin') && !mustBindEmail,
        ...securityState,
      },
    });
  }

  if (context.request.method == HttpMethod.patch) {
    final body = await tryParseJsonObject(context.request);
    if (body == null) {
      return errorResponse('invalid_request', 'Request body must be a JSON object.');
    }
    final nickname = body['nickname']?.toString();
    final newEmail = body['email']?.toString();
    final newPassword = body['new_password']?.toString();
    final currentPassword = body['current_password']?.toString() ?? '';

    if ((nickname == null || nickname.trim().isEmpty) &&
        (newEmail == null || newEmail.trim().isEmpty) &&
        (newPassword == null || newPassword.trim().isEmpty)) {
      return errorResponse(
        'invalid_request',
        'Provide at least one of nickname/email/new_password.',
      );
    }

    final result = await authService.updateSelfAccount(
      userId: user.id,
      currentPassword: currentPassword,
      nickname: nickname,
      newEmail: newEmail,
      newPassword: newPassword,
    );
    if (!result.ok) {
      return errorResponse(
        result.code ?? 'invalid_request',
        result.message ?? 'Update failed.',
        statusCode: result.statusCode,
      );
    }
    return jsonResponse({
      'updated': true,
      'updated_email': result.updatedEmail,
      'updated_password': result.updatedPassword,
      'updated_nickname': result.updatedNickname,
    });
  }

  return errorResponse('method_not_allowed', 'Use GET or PATCH.',
      statusCode: 405);
}
