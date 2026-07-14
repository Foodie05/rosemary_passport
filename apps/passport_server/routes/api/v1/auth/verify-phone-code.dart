import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/config/app_config.dart';
import '../../../../lib/src/services/phone_verification_service.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  final phoneNumber = (body?['phone_number'] ?? '').toString().trim();
  final verifyCode = (body?['verify_code'] ?? '').toString().trim();
  final countryCode = (body?['country_code'] ?? '86').toString().trim();

  if (phoneNumber.isEmpty || verifyCode.isEmpty) {
    return errorResponse('invalid_request', '请输入手机号和验证码。');
  }

  final requestIp = clientIpFromRequest(
    context.request,
    config: context.read<AppConfig>(),
  );
  if (requestIp == null || requestIp.isEmpty) {
    return errorResponse('invalid_request', '无法识别请求来源。');
  }

  final service = context.read<PhoneVerificationService>();
  try {
    final result = await service.verifyCode(
      phoneNumber: phoneNumber,
      verifyCode: verifyCode,
      requestIp: requestIp,
      countryCode: countryCode,
    );
    if (!result.ok) {
      return errorResponse(
        result.code ?? 'temporary_issue',
        result.message ?? '出现临时问题',
        statusCode: result.statusCode,
      );
    }
    return jsonResponse({'verified': true});
  } catch (_) {
    return errorResponse('temporary_issue', '验证码校验失败，请稍后重试。', statusCode: 503);
  }
}
