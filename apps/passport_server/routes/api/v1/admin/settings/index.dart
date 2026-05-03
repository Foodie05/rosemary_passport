import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  final service = context.read<AdminSettingsService>();

  if (context.request.method == HttpMethod.get) {
    final settings = await service.getSystemSettings();
    return jsonResponse({'settings': settings});
  }

  if (context.request.method == HttpMethod.put) {
    final body = await tryParseJsonObject(context.request);
    if (body == null) {
      return errorResponse('invalid_request', 'Request body must be a JSON object.');
    }
    await service.updateSystemSettings(body);
    return jsonResponse({'updated': true});
  }

  return errorResponse('method_not_allowed', 'Use GET or PUT.',
      statusCode: 405);
}
