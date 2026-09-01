import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/config/app_config.dart';
import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/services/email_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  if (body == null) return errorResponse('invalid_request', '请求体必须是 JSON 对象。');
  final method = (body['method'] ?? '').toString().trim();
  final excluded = (body['excluded_factor'] ?? '').toString().trim();
  final user = context.read<AuthenticatedUser>();
  try {
    final result = await context.read<AuthService>().sendStepUpCode(
      userId: user.id,
      method: method,
      excludedFactor: excluded,
      requestIp: clientIpFromRequest(
        context.request,
        config: context.read<AppConfig>(),
      ),
    );
    if (!result.ok) {
      return errorResponse(
        result.code ?? 'verification_failed',
        result.message ?? '验证码发送失败。',
        statusCode: result.statusCode,
      );
    }
    return jsonResponse({'sent': true, 'retry_after': 60});
  } on EmailDeliveryException {
    return errorResponse('temporary_issue', '验证码发送失败，请稍后重试。', statusCode: 503);
  } catch (_) {
    return errorResponse('temporary_issue', '验证码发送失败，请稍后重试。', statusCode: 503);
  }
}
