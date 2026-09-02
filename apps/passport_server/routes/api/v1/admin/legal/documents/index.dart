import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/repositories/legal_repository.dart';
import '../../../../../../lib/src/services/audit_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  final repository = context.read<LegalRepository>();
  if (context.request.method == HttpMethod.get) {
    return jsonResponse({'documents': await repository.listAll()});
  }
  if (context.request.method != HttpMethod.post) {
    return errorResponse(
      'method_not_allowed',
      'Use GET or POST.',
      statusCode: 405,
    );
  }
  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse('invalid_request', 'JSON object required.');
  }
  final type = (body['type'] ?? '').toString().trim();
  final title = (body['title'] ?? '').toString().trim();
  final content = (body['content'] ?? '').toString().trim();
  if (!const {'terms', 'privacy'}.contains(type) ||
      title.length < 3 ||
      title.length > 160 ||
      content.length < 200 ||
      content.length > 100000) {
    return errorResponse('invalid_request', '协议类型、标题或正文不符合要求。');
  }
  final actor = context.read<AuthenticatedUser>();
  final document = await repository.saveDraft(
    type: type,
    title: title,
    content: content,
    actorId: actor.id,
  );
  await context.read<AuditService>().log(
    action: 'admin.legal.draft.save',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'legal_document',
    resourceId: document['id'].toString(),
    metadata: {'type': type, 'version': document['version']},
    ip: context.request.headers['x-forwarded-for'],
  );
  return jsonResponse({'document': document}, statusCode: 201);
}
