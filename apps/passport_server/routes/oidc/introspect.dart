import 'package:dart_frog/dart_frog.dart';

import '../../lib/src/config/app_config.dart';
import '../../lib/src/services/oidc_service.dart';
import '../../lib/src/utils/http.dart';
import '../../lib/src/utils/oidc_error_page.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return oidcErrorResponse(
      context,
      code: 'method_not_allowed',
      message: 'Use POST.',
      statusCode: 405,
      title: '这个应用暂时无法校验登录状态',
      description: '应用使用了不受支持的令牌校验方式。',
    );
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return oidcErrorResponse(
      context,
      code: 'invalid_request',
      message: 'Request body must be a JSON object.',
      statusCode: 400,
      title: '这个应用暂时无法校验登录状态',
      description: '应用发来的令牌校验请求格式不正确。',
    );
  }
  final token = body['token']?.toString();
  final clientId = body['client_id']?.toString();
  final clientSecret = body['client_secret']?.toString();
  if (token == null || clientId == null) {
    return oidcErrorResponse(
      context,
      code: 'invalid_request',
      message: 'token and client_id are required.',
      statusCode: 400,
      title: '这个应用暂时无法校验登录状态',
      description: '应用缺少必要的令牌校验参数。',
    );
  }

  final result = await context.read<OidcService>().introspect(
    token: token,
    clientId: clientId,
    clientSecret: clientSecret,
    requestIp: clientIpFromRequest(
      context.request,
      config: context.read<AppConfig>(),
    ),
  );
  if (result == null) {
    return oidcErrorResponse(
      context,
      code: 'invalid_client',
      message: 'Client authentication failed.',
      statusCode: 401,
      title: '这个应用暂时无法校验登录状态',
      description: '应用未能通过 ROSM 的身份校验，因此无法继续验证登录状态。',
    );
  }
  return jsonResponse(result);
}
