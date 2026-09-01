import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  final challenge = (body?['step_up_challenge'] ?? '').toString().trim();
  if (challenge.isEmpty) {
    return errorResponse('invalid_request', '缺少登录验证参数。');
  }
  final options = await context.read<AuthService>().beginLoginStepUpPasskey(
    challenge: challenge,
    origin: context.request.headers['origin'] ?? '',
  );
  return options == null
      ? errorResponse('invalid_challenge', '登录验证已失效。', statusCode: 401)
      : jsonResponse(options);
}
