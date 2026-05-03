import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final result = await context
      .read<AdminSettingsService>()
      .testHcaptchaConnection();
  return jsonResponse(result, statusCode: result['ok'] == true ? 200 : 400);
}
