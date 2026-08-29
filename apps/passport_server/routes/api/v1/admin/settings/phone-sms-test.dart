import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../lib/src/services/audit_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final result = await context
      .read<AdminSettingsService>()
      .testPhoneSmsConfig();
  final actor = context.read<AuthenticatedUser>();
  await context.read<AuditService>().log(
    action: 'admin.integration_test.phone_sms',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'system_settings',
    resourceId: 'phone_sms',
    metadata: {'ok': result['ok'] == true},
    ip: context.request.headers['x-forwarded-for'],
  );
  if (result['ok'] != true) {
    return errorResponse(
      'invalid_request',
      (result['message'] ?? '短信配置不可用。').toString(),
    );
  }
  return jsonResponse(result);
}
