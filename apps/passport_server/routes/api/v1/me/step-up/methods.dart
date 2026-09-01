import 'package:dart_frog/dart_frog.dart';

import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/services/auth_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', '请使用 GET 请求。', statusCode: 405);
  }
  final excluded = context.request.uri.queryParameters['exclude']?.trim() ?? '';
  final user = context.read<AuthenticatedUser>();
  final methods = await context.read<AuthService>().availableStepUpMethods(
    userId: user.id,
    excludedFactor: excluded,
  );
  return jsonResponse({'methods': methods, 'excluded_factor': excluded});
}
