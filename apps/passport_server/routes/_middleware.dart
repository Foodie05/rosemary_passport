import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';

import '../lib/src/bootstrap.dart';
import '../lib/src/config/app_config.dart';
import '../lib/src/repositories/oidc_repository.dart';
import '../lib/src/repositories/user_repository.dart';
import '../lib/src/security/token_service.dart';
import '../lib/src/services/audit_service.dart';
import '../lib/src/services/admin_settings_service.dart';
import '../lib/src/services/auth_service.dart';
import '../lib/src/services/oidc_admin_service.dart';
import '../lib/src/services/oidc_service.dart';
import '../lib/src/services/security_service.dart';
import '../lib/src/services/token_validation_service.dart';
import '../lib/src/utils/http.dart';

Handler middleware(Handler handler) {
  final services = AppServices.instance;

  return handler
      .use(_errorBoundary())
      .use(provider<AppConfig>((_) => services.config))
      .use(provider<TokenService>((_) => services.tokenService))
      .use(
        provider<TokenValidationService>(
          (_) => services.tokenValidationService,
        ),
      )
      .use(provider<AuthService>((_) => services.authService))
      .use(provider<OidcAdminService>((_) => services.oidcAdminService))
      .use(provider<OidcService>((_) => services.oidcService))
      .use(provider<UserRepository>((_) => services.userRepository))
      .use(provider<OidcRepository>((_) => services.oidcRepository))
      .use(provider<AuditService>((_) => services.auditService))
      .use(provider<AdminSettingsService>((_) => services.adminSettingsService))
      .use(provider<SecurityService>((_) => services.securityService))
      .use(_securityHeaders());
}

Middleware _errorBoundary() {
  return (handler) {
    return (context) async {
      try {
        return await handler(context);
      } catch (error, stackTrace) {
        final request = context.request;
        final details = jsonEncode({
          'method': request.method.name,
          'path': request.uri.path,
          'query': request.uri.query,
          'content_type': request.headers['content-type'],
        });
        // ignore: avoid_print
        print('Unhandled request error: $details\n$error\n$stackTrace');
        return errorResponse('server_error', '服务器处理请求时发生错误。', statusCode: 500);
      }
    };
  };
}

Middleware _securityHeaders() {
  return (handler) {
    return (context) async {
      if (context.request.method == HttpMethod.options) {
        return jsonResponse(
          {'ok': true},
          statusCode: 204,
          headers: _corsHeaders(context.request, AppServices.instance.config),
        );
      }
      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          ..._corsHeaders(context.request, AppServices.instance.config),
          'strict-transport-security':
              response.headers['strict-transport-security'] ??
              'max-age=31536000; includeSubDomains; preload',
          'x-content-type-options':
              response.headers['x-content-type-options'] ?? 'nosniff',
          'x-frame-options': response.headers['x-frame-options'] ?? 'DENY',
          'referrer-policy':
              response.headers['referrer-policy'] ??
              'strict-origin-when-cross-origin',
          'content-security-policy':
              response.headers['content-security-policy'] ??
              "default-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
          'cache-control': response.headers['cache-control'] ?? 'no-store',
        },
      );
    };
  };
}

Map<String, String> _corsHeaders(Request request, AppConfig config) {
  final origin = request.headers['origin']?.trim() ?? '';
  if (origin.isEmpty || !config.corsAllowedOrigins.contains(origin)) {
    return {
      'vary': 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
    };
  }
  final requestedHeaders =
      request.headers['access-control-request-headers']?.trim() ?? '';
  final allowHeaders = requestedHeaders.isNotEmpty
      ? requestedHeaders
      : 'authorization,content-type,x-requested-with';
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': allowHeaders,
    'access-control-allow-credentials': 'true',
    'access-control-max-age': '3600',
    'vary': 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
  };
}
