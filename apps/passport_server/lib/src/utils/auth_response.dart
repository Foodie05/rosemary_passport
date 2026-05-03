import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';
import '../models/authenticated_user.dart';
import '../security/token_service.dart';
import '../services/auth_service.dart';
import 'auth_cookie.dart';
import 'http.dart';

Future<Map<String, dynamic>> buildFirstPartyAuthPayload(
  RequestContext context, {
  required AuthenticatedUser user,
  bool postRegistrationPasskeyBootstrap = false,
}) async {
  final mustBindEmail =
      user.roles.contains('admin') &&
      user.email.toLowerCase().trim().endsWith('@rosm.local');
  final securityState = await context.read<AuthService>().getSecurityState(
    userId: user.id,
  );

  return {
    'user': user.toJson(),
    'security': {
      'must_bind_email': mustBindEmail,
      'admin_mfa_required': user.roles.contains('admin') && !mustBindEmail,
      ...securityState,
    },
    'post_register_passkey_bootstrap': postRegistrationPasskeyBootstrap,
  };
}

Response authJsonResponse(
  RequestContext context,
  Map<String, dynamic> data, {
  int statusCode = 200,
  String? accessToken,
}) {
  final config = context.read<AppConfig>();
  return jsonResponse(
    data,
    statusCode: statusCode,
    headers: {
      if (accessToken != null && accessToken.isNotEmpty)
        'set-cookie': buildAccessTokenCookie(
          accessToken,
          config: config,
          maxAgeSeconds: context.read<TokenService>().accessTokenTtlSeconds,
        ),
    },
  );
}
