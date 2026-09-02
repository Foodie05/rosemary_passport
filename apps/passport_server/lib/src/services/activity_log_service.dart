import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../db/database.dart';
import '../security/token_service.dart';
import '../utils/auth_cookie.dart';

class ActivityLogService {
  ActivityLogService(this._database, this._config, this._tokens);

  final Database _database;
  final AppConfig _config;
  final TokenService _tokens;

  Future<void> recordRequest({
    required String method,
    required String path,
    required int statusCode,
    required String? authorization,
    required String? cookie,
    required String? ip,
    required String? userAgent,
  }) async {
    if (path == '/health/live' || path == '/health/ready') return;
    final normalizedPath = _normalizePath(path);
    final category = _category(normalizedPath);
    final actorId = _actorId(authorization, cookie);
    final outcome = statusCode < 400 ? 'success' : 'rejected';
    final risk = statusCode == 401 || statusCode == 403 || statusCode == 429
        ? 'security'
        : statusCode >= 500
        ? 'error'
        : 'normal';
    await _database.execute(
      '''
      insert into activity_logs(
        actor_id, category, action, route_template, method, outcome,
        status_code, risk_level, ip_hash, user_agent_hash, metadata
      ) values (
        cast(@actor_id as uuid), @category, @action, @route, @method,
        @outcome, @status_code, @risk, @ip_hash, @user_agent_hash,
        '{}'::jsonb
      )
      ''',
      params: {
        'actor_id': actorId,
        'category': category,
        'action': '$method $normalizedPath',
        'route': normalizedPath,
        'method': method,
        'outcome': outcome,
        'status_code': statusCode,
        'risk': risk,
        'ip_hash': _hash(ip),
        'user_agent_hash': _hash(userAgent),
      },
    );
  }

  String? _actorId(String? authorization, String? cookie) {
    final raw = authorization?.trim() ?? '';
    final token = raw.startsWith('Bearer ')
        ? raw.substring('Bearer '.length).trim()
        : readCookieValue(cookie, kAccessTokenCookieName);
    if (token == null || token.isEmpty) return null;
    final verified = _tokens.verify(token, expectedType: 'access');
    final subject = verified?.payload['sub']?.toString() ?? '';
    return RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(subject)
        ? subject
        : null;
  }

  String _normalizePath(String path) {
    final normalized = path
        .replaceAll(
          RegExp(
            r'/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',
            caseSensitive: false,
          ),
          '/:id',
        )
        .replaceAll(RegExp(r'/\d+(?=/|$)'), '/:number');
    return normalized.substring(0, normalized.length.clamp(0, 240));
  }

  String _category(String path) {
    if (path.startsWith('/api/v1/auth/')) return 'authentication';
    if (path.startsWith('/oidc/') || path.startsWith('/api/v1/oidc/')) {
      return 'authorization';
    }
    if (path.startsWith('/api/v1/admin/')) return 'administration';
    if (path.startsWith('/api/v1/me/')) return 'account';
    if (path.startsWith('/api/v1/legal/')) return 'legal';
    return 'service';
  }

  String? _hash(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    return Hmac(
      sha256,
      utf8.encode(_config.jwtBindingKey),
    ).convert(utf8.encode(normalized)).toString();
  }
}
