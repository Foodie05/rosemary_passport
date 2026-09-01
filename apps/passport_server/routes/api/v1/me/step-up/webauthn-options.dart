import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('method_not_allowed', '请使用 POST 请求。', statusCode: 405);
  }
  final body = await tryParseJsonObject(context.request);
  if (body == null) return errorResponse('invalid_request', '请求体必须是 JSON 对象。');
  final excluded = (body['excluded_factor'] ?? '').toString().trim();
  final user = context.read<AuthenticatedUser>();
  final options = await context.read<AuthService>().beginStepUpPasskey(
    userId: user.id,
    excludedFactor: excluded,
    origin: context.request.headers['origin'] ?? '',
  );
  if (options == null) {
    return errorResponse('invalid_factor', '当前不能使用通行密钥完成校验。', statusCode: 400);
  }
  return jsonResponse(options);
}
