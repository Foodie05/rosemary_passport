import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }

  final templates = await context.read<AdminSettingsService>().listTemplates();
  return jsonResponse({'templates': templates});
}
