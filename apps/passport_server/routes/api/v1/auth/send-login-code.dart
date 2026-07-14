import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/models/auth_requests.dart';
import '../../../../lib/src/services/auth_service.dart';
import '../../../../lib/src/services/email_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }

  final authService = context.read<AuthService>();
  final payload = await tryParseJsonModel(
    context.request,
    PasswordLoginRequest.fromJson,
  );
  if (payload == null ||
      payload.email.trim().isEmpty ||
      payload.password.isEmpty) {
    return errorResponse('invalid_request', '请输入邮箱和密码。');
  }
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
      return errorResponse('captcha_failed', '人机验证未通过，请重试。', statusCode: 400);
    }
  }
  try {
    final factorType = (payload.factorType ?? 'email_code').trim();
    final result = switch (factorType) {
      'email_code' => await authService.sendLoginCode(
        email: payload.email,
        password: payload.password,
        requestIp: requestIp,
      ),
      'phone_code' => await authService.sendPasswordPhoneLoginCode(
        email: payload.email,
        password: payload.password,
        requestIp: requestIp,
      ),
      _ => const AdminLoginCodeAttempt.failure(
        code: 'invalid_factor',
        message: '不支持的验证因子。',
        statusCode: 400,
      ),
    };
    if (!result.ok) {
      var response = errorResponse(
        result.code ?? 'temporary_issue',
        result.message ?? '出现临时问题',
        statusCode: result.statusCode,
      );
      if (result.statusCode == 429) {
        final retryAfter = await authService.mfaLoginCodeSendRetryAfter(
          email: payload.email,
          requestIp: requestIp,
        );
        response = response.copyWith(
          headers: {'retry-after': '${retryAfter ?? 60}'},
        );
      }
      return response;
    }
    return jsonResponse({
      'sent': !result.requiresBinding,
      'requires_binding': result.requiresBinding,
      'message': result.message ?? '验证码已发送。',
      'retry_after': await authService.mfaLoginCodeCooldownRetryAfter(
        email: payload.email,
      ),
    });
  } on EmailDeliveryException {
    return errorResponse('temporary_issue', '出现临时问题', statusCode: 503);
  } catch (_) {
    return errorResponse('temporary_issue', '出现临时问题', statusCode: 503);
  }
}
