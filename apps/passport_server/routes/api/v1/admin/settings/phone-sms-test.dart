import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final result = await context.read<AdminSettingsService>().testPhoneSmsConfig();
  if (result['ok'] != true) {
    return errorResponse('invalid_request', (result['message'] ?? '短信配置不可用。').toString());
  }
  return jsonResponse(result);
}
