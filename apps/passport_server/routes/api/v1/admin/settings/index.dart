import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/admin_settings_service.dart';
import '../../../../../lib/src/services/audit_service.dart';
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
      return errorResponse(
        'invalid_request',
        'Request body must be a JSON object.',
      );
    }
    try {
      await service.updateSystemSettings(body);
    } on FormatException catch (error) {
      return errorResponse('invalid_request', error.message);
    }
    final actor = context.read<AuthenticatedUser>();
    await context.read<AuditService>().log(
      action: 'admin.system_settings.update',
      actorId: actor.id,
      actorType: 'admin',
      resourceType: 'system_settings',
      resourceId: 'global',
      metadata: {'sections': body.keys.toList()..sort()},
      ip: context.request.headers['x-forwarded-for'],
    );
    return jsonResponse({'updated': true});
  }

  return errorResponse(
    'method_not_allowed',
    'Use GET or PUT.',
    statusCode: 405,
  );
}
