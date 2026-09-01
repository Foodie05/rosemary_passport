import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/config/app_config.dart';
import '../../../../../../lib/src/services/auth_service.dart';
import '../../../../../../lib/src/utils/http.dart';
import '../../../../../../lib/src/utils/step_up_http.dart';

Future<Response> onRequest(RequestContext context, String credentialId) async {
  if (context.request.method != HttpMethod.delete) {
    return errorResponse('method_not_allowed', 'Use DELETE.', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) return errorResponse('invalid_request', '请提供二次验证信息。');
  final user = context.read<AuthenticatedUser>();
  final authService = context.read<AuthService>();
  final stepUp = await authService.verifyStepUp(
    userId: user.id,
    excludedFactor: 'passkey',
    proof: stepUpProofFromBody(body),
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
  await authService.deleteWebAuthnCredential(
    userId: user.id,
    credentialId: credentialId,
  );
  return jsonResponse({'deleted': true});
}
