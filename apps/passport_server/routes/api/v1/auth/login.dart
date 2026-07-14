import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/auth_requests.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/utils/auth_response.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final payload = await tryParseJsonModel(
    context.request,
    PasswordLoginRequest.fromJson,
  );
  if (payload == null ||
      payload.email.trim().isEmpty ||
      payload.password.isEmpty) {
    return errorResponse('invalid_request', '请输入邮箱和密码。');
  }
  final authService = context.read<AuthService>();
  final bypassCaptcha = await authService.shouldBypassBootstrapCaptcha(
    email: payload.email,
    password: payload.password,
  );
  if (!bypassCaptcha && (payload.captchaToken?.trim().isEmpty ?? true)) {
    return errorResponse('invalid_request', '请先完成人机验证。');
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  if (!bypassCaptcha) {
    final captchaOk = await authService.verifyCaptcha(
      payload.captchaToken!.trim(),
      ip: requestIp,
    );
    if (!captchaOk) {
      return errorResponse(
        'captcha_failed',
        '人机验证未通过，请重试。',
        statusCode: 400,
      );
    }
  }
  final attempt = await authService.login(
    email: payload.email,
    password: payload.password,
    factorType: payload.factorType,
    emailCode: payload.emailCode,
    phoneCode: payload.phoneCode,
    authenticatorCode: payload.authenticatorCode,
    requestIp: requestIp,
  );
  if (!attempt.ok) {
    var response = errorResponse(
      attempt.code ?? 'login_failed',
      attempt.message ?? '账号或密码错误。',
      statusCode: attempt.statusCode,
    );
    if (attempt.statusCode == 429) {
      final retryAfter = await authService.loginRetryAfter(
        email: payload.email,
        requestIp: requestIp,
      );
      response = response.copyWith(
        headers: {'retry-after': '${retryAfter ?? 60}'},
      );
    }
    return response;
  }
  final result = attempt.result!;
  final responseBody = await buildFirstPartyAuthPayload(
    context,
    user: result.user,
  );
  return authJsonResponse(
    context,
    responseBody,
    accessToken: result.tokens.accessToken,
  );
}
