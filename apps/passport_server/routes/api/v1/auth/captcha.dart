import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/models/auth_requests.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', 'Use POST.', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
    context.request,
    CaptchaRequest.fromJson,
  );
  if (payload == null || payload.captchaToken.isEmpty) {
    return errorResponse('invalid_request', 'captcha_token is required.');
  }

  final ok = await context.read<AuthService>().verifyCaptcha(
        payload.captchaToken,
        ip: clientIpFromRequest(context.request),
      );
  if (!ok) {
    return errorResponse('captcha_failed', 'Captcha verification failed.',
        statusCode: 400);
  }

  return jsonResponse({'verified': true});
}
