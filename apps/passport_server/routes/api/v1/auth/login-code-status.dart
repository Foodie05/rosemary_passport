import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }

  final email = context.request.uri.queryParameters['email']?.trim() ?? '';
  final flow = context.request.uri.queryParameters['flow']?.trim() ?? 'login';
  if (email.isEmpty) {
    return errorResponse('invalid_request', 'email is required.');
  }

  final authService = context.read<AuthService>();
  final retryAfter = flow == 'mfa'
      ? await authService.mfaLoginCodeCooldownRetryAfter(email: email)
      : await authService.loginCodeCooldownRetryAfter(email: email);

  return jsonResponse({
    'email': email,
    'flow': flow,
    'retry_after': retryAfter ?? 0,
    'cooling_down': (retryAfter ?? 0) > 0,
  });
}
