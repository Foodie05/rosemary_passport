import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/config/app_config.dart';
import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/repositories/security_repository.dart';
import '../../../../../../lib/src/services/audit_service.dart';
import '../../../../../../lib/src/utils/http.dart';

const _subjectTypes = {'all', 'email', 'phone', 'ip'};

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return _list(context);
  }
  if (context.request.method == HttpMethod.delete) {
    return _reset(context);
  }
  return errorResponse(
    'method_not_allowed',
    'Use GET or DELETE.',
    statusCode: 405,
  );
}

Future<Response> _list(RequestContext context) async {
  final query = context.request.uri.queryParameters;
  final page = int.tryParse(query['page'] ?? '') ?? 1;
  final pageSize = int.tryParse(query['page_size'] ?? '') ?? 25;
  final search = (query['search'] ?? '').trim();
  final subjectType = (query['subject_type'] ?? 'all').trim();
  final activeOnly = query['active_only'] == 'true';
  if (page < 1 || pageSize < 1 || pageSize > 100 || search.length > 200) {
    return errorResponse('invalid_request', '分页或搜索参数不符合要求。');
  }
  if (!_subjectTypes.contains(subjectType)) {
    return errorResponse('invalid_request', '主体类型不符合要求。');
  }

  final result = await context
      .read<SecurityRepository>()
      .listVerificationCodeThrottles(
        limit: pageSize,
        offset: (page - 1) * pageSize,
        search: search,
        subjectType: subjectType,
        activeOnly: activeOnly,
      );
  return jsonResponse(
    {
      'cooldowns': result.records.map((record) => record.toJson()).toList(),
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'pagination': {
        'page': page,
        'page_size': pageSize,
        'total': result.total,
        'total_pages': result.total == 0
            ? 0
            : ((result.total + pageSize - 1) ~/ pageSize),
      },
    },
    headers: {'cache-control': 'no-store'},
  );
}

Future<Response> _reset(RequestContext context) async {
  final body = await tryParseJsonObject(context.request);
  final scope = (body?['scope'] ?? '').toString().trim();
  final subject = (body?['subject'] ?? '').toString().trim();
  if (!scope.startsWith('verification-code:') ||
      scope.length > 160 ||
      subject.isEmpty ||
      subject.length > 320) {
    return errorResponse('invalid_request', '冷却记录不符合要求。');
  }

  final repository = context.read<SecurityRepository>();
  final deleted = await repository.deleteVerificationCodeThrottle(
    scope: scope,
    subject: subject,
  );
  if (!deleted) {
    return errorResponse('not_found', '冷却记录不存在。', statusCode: 404);
  }

  final actor = context.read<AuthenticatedUser>();
  final subjectType = scope.endsWith(':ip')
      ? 'ip'
      : scope.endsWith(':phone')
      ? 'phone'
      : 'email';
  await context.read<AuditService>().log(
    action: 'admin.cooldown.reset',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'verification_code_throttle',
    resourceId: scope,
    metadata: {'scope': scope, 'subject_type': subjectType},
    ip: clientIpFromRequest(context.request, config: context.read<AppConfig>()),
  );
  return jsonResponse({'reset': true});
}
