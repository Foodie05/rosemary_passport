import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../lib/src/services/audit_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final body = await context.request.json();
  final payload = body is Map
      ? Map<String, dynamic>.from(body)
      : <String, dynamic>{};
  final token = (payload['captcha_token'] ?? '').toString().trim();
  if (token.isEmpty) {
    return errorResponse('invalid_request', '请先完成阿里云验证码验证。');
  }

  final result = await context
      .read<AdminSettingsService>()
      .testAliyunCaptchaConnection(token);
  final actor = context.read<AuthenticatedUser>();
  await context.read<AuditService>().log(
    action: 'admin.integration_test.captcha',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'system_settings',
    resourceId: 'aliyun_captcha',
    metadata: {'ok': result['ok'] == true},
    ip: context.request.headers['x-forwarded-for'],
  );
  return jsonResponse(result, statusCode: result['ok'] == true ? 200 : 400);
}
