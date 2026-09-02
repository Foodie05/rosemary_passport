import 'package:dart_frog/dart_frog.dart';

import '../../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../../lib/src/repositories/legal_repository.dart';
import '../../../../../../../lib/src/services/audit_service.dart';
import '../../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }
  final actor = context.read<AuthenticatedUser>();
  final document = await context.read<LegalRepository>().publish(
    documentId: id,
    actorId: actor.id,
  );
  if (document == null) {
    return errorResponse('not_found', '未找到可发布的草稿。', statusCode: 404);
  }
  await context.read<AuditService>().log(
    action: 'admin.legal.publish',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'legal_document',
    resourceId: id,
    metadata: {'type': document['type'], 'version': document['version']},
    ip: context.request.headers['x-forwarded-for'],
  );
  return jsonResponse({'document': document});
}
