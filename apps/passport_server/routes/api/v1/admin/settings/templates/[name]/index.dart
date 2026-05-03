import 'package:dart_frog/dart_frog.dart';

import '../../../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context, String name) async {
  final service = context.read<AdminSettingsService>();

  if (context.request.method == HttpMethod.get) {
    final template = await service.getTemplate(name);
    if (template == null) {
      return errorResponse('not_found', 'Template not found.', statusCode: 404);
    }
    return jsonResponse({'template': template});
  }

  if (context.request.method == HttpMethod.put) {
    final body = await tryParseJsonObject(context.request);
    if (body == null) {
      return errorResponse('invalid_request', 'Request body must be a JSON object.');
    }
    final subject = body['subject']?.toString() ?? '';
    final html = body['html']?.toString() ?? '';
    final text = body['text']?.toString() ?? '';
    if (subject.isEmpty || html.isEmpty || text.isEmpty) {
      return errorResponse(
          'invalid_request', 'subject/html/text are required.');
    }

    await service.upsertTemplate(
      name: name,
      subject: subject,
      html: html,
      text: text,
    );
    return jsonResponse({'updated': true});
  }

  return errorResponse('method_not_allowed', 'Use GET or PUT.',
      statusCode: 405);
}
