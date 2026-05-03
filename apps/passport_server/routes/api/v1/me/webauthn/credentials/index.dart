import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/services/auth_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }

  final user = context.read<AuthenticatedUser>();
  final credentials = await context.read<AuthService>().listWebAuthnCredentials(
        userId: user.id,
      );
  return jsonResponse({'credentials': credentials, 'max_count': 5});
}
