import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/models/authenticated_user.dart';
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

  final phoneNumber = (body['phone_number'] ?? '').toString();
  final currentPassword = (body['current_password'] ?? '').toString();
  final verifyCode = (body['verify_code'] ?? '').toString();
  if (phoneNumber.trim().isEmpty || currentPassword.trim().isEmpty || verifyCode.trim().isEmpty) {
    return errorResponse('invalid_request', 'phone_number, current_password and verify_code are required.');
  }

  final user = context.read<AuthenticatedUser>();
  final result = await context.read<AuthService>().bindPhoneWithCode(
        userId: user.id,
        phoneNumber: phoneNumber,
        currentPassword: currentPassword,
        verifyCode: verifyCode,
      );

  if (!result.ok) {
    return errorResponse(
      result.code ?? 'invalid_request',
      result.message ?? 'Request failed.',
      statusCode: result.statusCode,
    );
  }

  return jsonResponse({'updated': true});
}
