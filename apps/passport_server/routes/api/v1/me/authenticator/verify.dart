import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/config/app_config.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/utils/http.dart';
import '../../../../../lib/src/utils/step_up_http.dart';

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
  final secret = body['secret']?.toString() ?? '';
  final code = body['code']?.toString() ?? '';
  if (secret.trim().isEmpty || code.trim().isEmpty) {
    return errorResponse(
      'invalid_request',
      'current_password, secret and code are required.',
    );
  }

  final user = context.read<AuthenticatedUser>();
  final authService = context.read<AuthService>();
  final stepUp = await authService.verifyStepUp(
    userId: user.id,
    excludedFactor: 'authenticator',
    proof: stepUpProofFromBody(body, legacyPassword: currentPassword),
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
  final result = await authService.verifyAuthenticatorSetup(
    userId: user.id,
    currentPassword: currentPassword,
    secret: secret,
    code: code,
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
