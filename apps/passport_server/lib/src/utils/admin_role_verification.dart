import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';
import '../models/authenticated_user.dart';
import '../services/auth_service.dart';
import 'http.dart';
import 'step_up_http.dart';

const adminRoleMfaMethods = {
  'email_code',
  'phone_code',
  'authenticator',
  'passkey',
};

/// Verify the acting administrator, never the target user or a body-supplied ID.
Future<Response?> verifyAdminRoleAssignment(
  RequestContext context,
  Map<String, dynamic> body,
) async {
  final actor = context.read<AuthenticatedUser>();
  if (!actor.isAdmin || actor.isBanned) {
    return errorResponse('forbidden', '需要管理员权限。', statusCode: 403);
  }
  final proof = stepUpProofFromBody(body);
  if (!adminRoleMfaMethods.contains(proof['method'])) {
    return errorResponse(
      'mfa_required',
      '应用角色更改前，请完成一种已绑定的 MFA 验证。',
      statusCode: 401,
    );
  }
  final result = await context.read<AuthService>().verifyStepUp(
    userId: actor.id,
    excludedFactor: 'password',
    proof: proof,
    requestIp: clientIpFromRequest(
      context.request,
      config: context.read<AppConfig>(),
    ),
  );
  if (!result.ok) {
    return errorResponse(
      result.code ?? 'verification_failed',
      result.message ?? '二次验证未通过，请重试。',
      statusCode: result.statusCode,
    );
  }
  return null;
}
