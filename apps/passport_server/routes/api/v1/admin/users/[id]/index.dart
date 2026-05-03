import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/repositories/user_repository.dart';
import '../../../../../../lib/src/services/audit_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return errorResponse('method_not_allowed', 'Use DELETE.', statusCode: 405);
  }

  final actor = context.read<AuthenticatedUser>();
  if (actor.id == id) {
    return errorResponse('forbidden', 'cannot delete current admin user.', statusCode: 403);
  }

  final repository = context.read<UserRepository>();
  final existing = await repository.findById(id);
  if (existing == null) {
    return errorResponse('not_found', 'user not found.', statusCode: 404);
  }

  await repository.deleteUser(userId: id);

  await context.read<AuditService>().log(
        action: 'admin.user.delete',
        actorId: actor.id,
        actorType: 'admin',
        resourceType: 'user',
        resourceId: id,
        metadata: {
          'email': existing.email,
          'nickname': existing.nickname,
          'roles': existing.roles,
        },
        ip: context.request.headers['x-forwarded-for'],
      );

  return jsonResponse({'deleted': true});
}
