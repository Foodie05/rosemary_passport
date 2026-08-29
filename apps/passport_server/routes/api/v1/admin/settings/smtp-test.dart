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
      .testSmtpConnection();
  final actor = context.read<AuthenticatedUser>();
  await context.read<AuditService>().log(
    action: 'admin.integration_test.smtp',
    actorId: actor.id,
    actorType: 'admin',
    resourceType: 'system_settings',
    resourceId: 'smtp',
    metadata: {'ok': result['ok'] == true},
    ip: context.request.headers['x-forwarded-for'],
  );
  return jsonResponse(result, statusCode: result['ok'] == true ? 200 : 400);
}
