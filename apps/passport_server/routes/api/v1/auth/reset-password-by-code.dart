import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse('invalid_request', '请求体必须是 JSON 对象。');
  }
  final account = (body['account'] ?? '').toString().trim();
  final method = (body['method'] ?? '').toString().trim();
  final code = (body['code'] ?? '').toString().trim();
  final newPassword = (body['new_password'] ?? '').toString();
  if (account.isEmpty || method.isEmpty || code.isEmpty || newPassword.isEmpty) {
    return errorResponse('invalid_request', 'account, method, code and new_password are required.');
  }

  final requestIp = clientIpFromRequest(context.request, config: context.read<AppConfig>());
  final result = await context.read<AuthService>().recoverPasswordWithCode(
    account: account,
    method: method,
    code: code,
    newPassword: newPassword,
    requestIp: requestIp,
  );
  if (!result.ok) {
    return errorResponse(result.code ?? 'invalid_request', result.message ?? '重置失败。', statusCode: result.statusCode);
  }
  return jsonResponse({'updated': true});
}
