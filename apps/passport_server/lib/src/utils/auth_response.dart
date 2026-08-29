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
  TokenPair? tokens,
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
    if (tokens != null) 'tokens': tokens.toJson(),
    'post_register_passkey_bootstrap': postRegistrationPasskeyBootstrap,
  };
}

Response authJsonResponse(
  RequestContext context,
  Map<String, dynamic> data, {
  int statusCode = 200,
  String? accessToken,
  int? accessTokenMaxAgeSeconds,
  String? refreshToken,
  int? refreshTokenMaxAgeSeconds,
}) {
  final config = context.read<AppConfig>();
  return jsonResponse(
    data,
    statusCode: statusCode,
    headers: {
      if ((accessToken != null && accessToken.isNotEmpty) ||
          (refreshToken != null && refreshToken.isNotEmpty))
        'set-cookie': <String>[
          if (accessToken != null && accessToken.isNotEmpty)
            buildAccessTokenCookie(
              accessToken,
              config: config,
              maxAgeSeconds:
                  accessTokenMaxAgeSeconds ??
                  context.read<TokenService>().accessTokenTtlSeconds,
            ),
          if (refreshToken != null && refreshToken.isNotEmpty)
            buildRefreshTokenCookie(
              refreshToken,
              config: config,
              maxAgeSeconds:
                  refreshTokenMaxAgeSeconds ??
                  context.read<TokenService>().refreshTokenTtlSeconds,
            ),
        ],
    },
  );
}
