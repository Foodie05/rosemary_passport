import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/repositories/oidc_repository.dart';
import '../../../../../../lib/src/repositories/user_repository.dart';
import '../../../../../../lib/src/services/audit_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return errorResponse('method_not_allowed', 'Use PATCH.', statusCode: 405);
  }
  final actor = context.read<AuthenticatedUser>();
  if (actor.id == id) {
    return errorResponse('forbidden', '不能封禁当前管理员账户。', statusCode: 403);
  }
  final body = await tryParseJsonObject(context.request);
  final status = (body?['status'] ?? '').toString().trim();
  final reason = (body?['reason'] ?? '').toString().trim();
  if (!const {'active', 'banned'}.contains(status) ||
      (status == 'banned' && (reason.length < 3 || reason.length > 1000))) {
    return errorResponse('invalid_request', '状态或封禁原因不符合要求。');
  }
  final repository = context.read<UserRepository>();
  final existing = await repository.findById(id);
  if (existing == null) {
    return errorResponse('not_found', 'user not found.', statusCode: 404);
  }
  await repository.updateAccountStatus(
    userId: id,
    status: status,
    reason: status == 'banned' ? reason : null,
    actorId: actor.id,
  );
  if (status == 'banned') {
    await Future.wait([
      context.read<OidcRepository>().revokeRefreshTokensForUser(id),
      context.read<OidcRepository>().revokeAccessTokensForUser(id),
    ]);
  }
  await context.read<AuditService>().log(
    action: status == 'banned' ? 'admin.user.ban' : 'admin.user.unban',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'user',
    resourceId: id,
    metadata: {
      'previous_status': existing.accountStatus,
      'new_status': status,
      if (status == 'banned') 'reason': reason,
    },
    ip: context.request.headers['x-forwarded-for'],
  );
  return jsonResponse({'updated': true, 'status': status});
}
