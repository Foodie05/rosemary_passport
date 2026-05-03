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
      title: '这个应用暂时无法完成登录',
      description: '应用向 ROSM 发起了不受支持的令牌请求方式。',
    );
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return oidcErrorResponse(
      context,
      code: 'invalid_request',
      message: 'Request body must be a JSON object.',
      statusCode: 400,
      title: '这个应用暂时无法完成登录',
      description: '应用发来的令牌请求格式不正确，ROSM 无法继续处理。',
    );
  }
  final grantType = body['grant_type']?.toString();
  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  if (grantType == null) {
    return oidcErrorResponse(
      context,
      code: 'invalid_request',
      message: 'grant_type is required.',
      statusCode: 400,
      title: '这个应用暂时无法完成登录',
      description: '应用没有提供必要的授权类型参数。',
    );
  }

  if (grantType == 'authorization_code') {
    final code = body['code']?.toString();
    final clientId = body['client_id']?.toString();
    final clientSecret = body['client_secret']?.toString();
    final redirectUri = body['redirect_uri']?.toString();
    final codeVerifier = body['code_verifier']?.toString();

    if (code == null || clientId == null || redirectUri == null) {
      return oidcErrorResponse(
        context,
        code: 'invalid_request',
        message: 'code, client_id, redirect_uri are required.',
        statusCode: 400,
        title: '这个应用暂时无法完成登录',
        description: '应用缺少必要的授权码交换参数，ROSM 无法完成登录确认。',
      );
    }

    final tokens = await context.read<OidcService>().exchangeCode(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri,
      clientSecret: clientSecret,
      codeVerifier: codeVerifier,
    );

    if (tokens == null) {
      return oidcErrorResponse(
        context,
        code: 'invalid_grant',
        message: 'Authorization code exchange failed.',
        statusCode: 400,
        title: '这个应用暂时无法完成登录',
        description: '应用未能正确完成授权码交换，ROSM 无法向它确认登录结果。',
      );
    }
    return jsonResponse(tokens);
  }

  if (grantType == 'refresh_token') {
    final refreshToken = body['refresh_token']?.toString();
    final clientId = body['client_id']?.toString();
    final clientSecret = body['client_secret']?.toString();
    if (refreshToken == null || clientId == null) {
      return oidcErrorResponse(
        context,
        code: 'invalid_request',
        message: 'refresh_token and client_id are required.',
        statusCode: 400,
        title: '这个应用暂时无法继续访问',
        description: '应用缺少必要的刷新参数，ROSM 无法为它续签登录状态。',
      );
    }

    final pair = await context.read<OidcService>().refreshTokenGrant(
      refreshToken: refreshToken,
      clientId: clientId,
      clientSecret: clientSecret,
      requestIp: requestIp,
    );
    if (pair == null) {
      return oidcErrorResponse(
        context,
        code: 'invalid_grant',
        message: 'Refresh token invalid.',
        statusCode: 400,
        title: '这个应用暂时无法继续访问',
        description: '应用提交的刷新凭据无效，ROSM 无法继续维持这次登录。',
      );
    }
    return jsonResponse(pair);
  }

  return oidcErrorResponse(
    context,
    code: 'unsupported_grant_type',
    message: 'Only authorization_code and refresh_token are supported.',
    statusCode: 400,
    title: '这个应用暂时无法完成登录',
    description: '应用请求了当前不受支持的授权类型。',
  );
}
