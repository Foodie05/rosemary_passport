import 'package:dart_frog/dart_frog.dart';

import '../../lib/src/services/oidc_service.dart';
import '../../lib/src/utils/http.dart';
import '../../lib/src/utils/oidc_error_page.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return oidcErrorResponse(
      context,
      code: 'method_not_allowed',
      message: 'Use GET.',
      statusCode: 405,
      title: '这个应用暂时无法读取您的信息',
      description: '应用使用了不受支持的用户信息请求方式。',
    );
  }

  final auth = context.request.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) {
    return oidcErrorResponse(
      context,
      code: 'unauthorized',
      message: 'Bearer token required.',
      statusCode: 401,
      title: '这个应用暂时无法读取您的信息',
      description: '应用没有带上有效的登录凭据，因此 ROSM 无法返回您的账户信息。',
    );
  }

  final token = auth.substring(7);
  final userInfo = await context.read<OidcService>().userInfo(token);
  if (userInfo == null) {
    return oidcErrorResponse(
      context,
      code: 'invalid_token',
      message: 'Token invalid.',
      statusCode: 401,
      title: '这个应用暂时无法读取您的信息',
      description: '应用提供的登录凭据已经失效或无效，ROSM 无法继续返回账户信息。',
    );
  }
  return jsonResponse(userInfo);
}
