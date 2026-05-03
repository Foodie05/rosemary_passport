import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../../lib/src/services/auth_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(
  RequestContext context,
  String credentialId,
) async {
  if (context.request.method != HttpMethod.delete) {
    return errorResponse('method_not_allowed', 'Use DELETE.', statusCode: 405);
  }

  final user = context.read<AuthenticatedUser>();
  await context.read<AuthService>().deleteWebAuthnCredential(
        userId: user.id,
        credentialId: credentialId,
      );
  return jsonResponse({'deleted': true});
}
