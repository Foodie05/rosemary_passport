import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../lib/src/bootstrap.dart';
import '../lib/src/config/app_config.dart';
import '../lib/src/repositories/oidc_repository.dart';
import '../lib/src/repositories/user_repository.dart';
import '../lib/src/security/token_service.dart';
import '../lib/src/security/password_policy.dart';
import '../lib/src/services/audit_service.dart';
import '../lib/src/services/admin_settings_service.dart';
import '../lib/src/services/auth_service.dart';
import '../lib/src/services/oidc_admin_service.dart';
import '../lib/src/services/oidc_service.dart';
import '../lib/src/services/phone_verification_service.dart';
import '../lib/src/services/security_service.dart';
import '../lib/src/services/token_validation_service.dart';
import '../lib/src/utils/http.dart';

class _RequestTrace {
  const _RequestTrace(this.id);

  final String id;
}

Handler middleware(Handler handler) {
  final services = AppServices.instance;

  return handler
      .use(_errorBoundary())
      .use(_requestLogging())
      .use(_drainControl())
      .use(provider<AppConfig>((_) => services.config))
      .use(provider<TokenService>((_) => services.tokenService))
      .use(provider<PasswordPolicy>((_) => services.passwordPolicy))
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
      .use(
        provider<PhoneVerificationService>(
          (_) => services.phoneVerificationService,
        ),
      )
      .use(_securityHeaders());
}

Middleware _drainControl() {
  return (handler) {
    return (context) async {
      final coordinator = AppServices.instance.shutdownCoordinator;
      final path = context.request.uri.path;
      final isHealthCheck = path == '/health/live' || path == '/health/ready';
      if (isHealthCheck && coordinator.isDraining) {
        return handler(context);
      }
      if (!coordinator.tryEnter()) {
        return errorResponse(
          'service_draining',
          '服务正在维护，请稍后重试。',
          statusCode: 503,
        ).copyWith(headers: {'retry-after': '10'});
      }
      try {
        return await handler(context);
      } finally {
        coordinator.leave();
      }
    };
  };
}

Middleware _errorBoundary() {
  return (handler) {
    return (context) async {
      try {
        return await handler(context);
      } catch (error, stackTrace) {
        final request = context.request;
        String? requestId;
        try {
          requestId = context.read<_RequestTrace>().id;
        } catch (_) {
          requestId = request.headers['x-request-id'];
        }
        final details = jsonEncode({
          'level': 'error',
          'event': 'request.unhandled_error',
          'method': request.method.name,
          'path': request.uri.path,
          'request_id': requestId,
          'error_type': error.runtimeType.toString(),
        });
        // ignore: avoid_print
        print(details);
        if (Uri.parse(AppServices.instance.config.serverBaseUrl).host ==
            'localhost') {
          // ignore: avoid_print
          print(stackTrace);
        }
        return errorResponse('server_error', '服务器处理请求时发生错误。', statusCode: 500);
      }
    };
  };
}

Middleware _requestLogging() {
  const uuid = Uuid();
  return (handler) {
    return (context) async {
      final requestId = context.request.headers['x-request-id']?.trim();
      final resolvedRequestId = requestId == null || requestId.isEmpty
          ? uuid.v4()
          : requestId.substring(0, requestId.length.clamp(0, 128));
      final started = DateTime.now().toUtc();
      final nextContext = context.provide<_RequestTrace>(
        () => _RequestTrace(resolvedRequestId),
      );
      final response = await handler(nextContext);
      final duration = DateTime.now()
          .toUtc()
          .difference(started)
          .inMilliseconds;
      // ignore: avoid_print
      print(
        jsonEncode({
          'level': 'info',
          'event': 'request.completed',
          'request_id': resolvedRequestId,
          'method': context.request.method.name,
          'path': context.request.uri.path,
          'status': response.statusCode,
          'duration_ms': duration,
        }),
      );
      return response.copyWith(headers: {'x-request-id': resolvedRequestId});
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
          'permissions-policy':
              response.headers['permissions-policy'] ??
              'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
          'cross-origin-opener-policy':
              response.headers['cross-origin-opener-policy'] ?? 'same-origin',
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
      'vary':
          'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
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
    'vary':
        'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
  };
}
