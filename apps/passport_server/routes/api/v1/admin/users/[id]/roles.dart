import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/repositories/user_repository.dart';
import '../../../../../../lib/src/services/audit_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.patch) {
    return errorResponse('method_not_allowed', 'Use PATCH.', statusCode: 405);
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse('invalid_request', 'Request body must be a JSON object.');
  }
  final rawRoles = body['roles'];
  if (rawRoles is! List) {
    return errorResponse('invalid_request', 'roles must be an array.');
  }

  final roles = rawRoles
      .map((e) => e.toString().trim())
      .where((role) => role.isNotEmpty)
      .toSet()
      .toList();
  if (roles.isEmpty) {
    return errorResponse(
      'invalid_request',
      'roles must contain at least one non-empty role.',
    );
  }
  if (!roles.every(AuthenticatedUser.allowedRoles.contains)) {
    return errorResponse(
      'invalid_request',
      'roles contains unsupported values.',
    );
  }

  final repository = context.read<UserRepository>();
  final existing = await repository.findById(id);
  if (existing == null) {
    return errorResponse('not_found', 'user not found.', statusCode: 404);
  }
  if (roles.contains('admin') &&
      existing.email.toLowerCase().endsWith('@rosm.local')) {
    return errorResponse(
      'invalid_request',
      'reserved bootstrap admin email cannot receive admin privileges.',
    );
  }

  await repository.updateRoles(userId: id, roles: roles);

  final actor = context.read<AuthenticatedUser>();
  await context.read<AuditService>().log(
        action: 'admin.user.roles.update',
        actorId: actor.id,
        actorType: 'admin',
        resourceType: 'user',
        resourceId: id,
        metadata: {'roles': roles},
        ip: context.request.headers['x-forwarded-for'],
      );

  return jsonResponse({'updated': true});
}
