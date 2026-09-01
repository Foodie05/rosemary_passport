import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/models/authenticated_user.dart';
import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';
import '../../../../lib/src/utils/step_up_http.dart';

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

  final newPassword = body['new_password']?.toString() ?? '';
  final emailCode = body['email_code']?.toString() ?? '';
  if (newPassword.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      'new_password and email_code are required.',
    );
  }

  final user = context.read<AuthenticatedUser>();
  final authService = context.read<AuthService>();
  final stepUp = await authService.verifyStepUp(
    userId: user.id,
    excludedFactor: 'password',
    proof: stepUpProofFromBody(body, legacyEmailCode: emailCode),
    requestIp: clientIpFromRequest(
      context.request,
      config: context.read<AppConfig>(),
    ),
  );
  if (!stepUp.ok) {
    return errorResponse(
      stepUp.code ?? 'verification_failed',
      stepUp.message ?? '二次验证失败。',
      statusCode: stepUp.statusCode,
    );
  }
  final result = await authService.resetPasswordWithCode(
    userId: user.id,
    newPassword: newPassword,
    emailCode: emailCode,
    stepUpVerified: true,
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
