import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/services/auth_service.dart';
import '../../../../../../lib/src/utils/http.dart';

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
  final usePostRegistrationBootstrap = body['post_register_bootstrap'] == true;
  if (!usePostRegistrationBootstrap && currentPassword.trim().isEmpty) {
    return errorResponse('invalid_request', 'current_password is required.');
  }

  final user = context.read<AuthenticatedUser>();
  // Only a freshly self-registered session may use this bootstrap path.
  // All ordinary "add passkey" flows must keep the current-password check.
  if (usePostRegistrationBootstrap &&
      !user.canBootstrapPasskeyAfterRegistration) {
    return errorResponse(
      'reauth_required',
      '本次免验证添加通行密钥的引导已失效，请输入当前密码后再试。',
      statusCode: 401,
    );
  }
  final origin = context.request.headers['origin'] ?? '';
  try {
    final options = await context.read<AuthService>().beginWebAuthnRegistration(
      userId: user.id,
      currentPassword: currentPassword,
      origin: origin,
      allowPostRegistrationBootstrap: usePostRegistrationBootstrap,
    );
    if (options == null) {
      if (usePostRegistrationBootstrap) {
        return errorResponse(
          'bootstrap_unavailable',
          '当前无法继续完成本次通行密钥引导，请稍后在账户安全中重试。',
          statusCode: 400,
        );
      }
      return errorResponse('invalid_password', '当前密码错误。', statusCode: 401);
    }
    return jsonResponse(options);
  } on Exception catch (error) {
    if (error.runtimeType.toString() == '_CredentialLimitException') {
      return errorResponse(
        'credential_limit_reached',
        '最多只能创建 5 个系统通行密钥。',
        statusCode: 409,
      );
    }
    if (error is WebAuthnUnavailableException) {
      return errorResponse(
        'webauthn_unavailable',
        '当前服务器未启用通行密钥，请稍后再试。',
        statusCode: 503,
      );
    }
    rethrow;
  }
}
