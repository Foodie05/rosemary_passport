import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/services/audit_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }

  final audits = await context.read<AuditService>().list();
  return jsonResponse({'audits': audits});
}
