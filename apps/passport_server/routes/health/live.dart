import 'package:dart_frog/dart_frog.dart';

import '../../lib/src/utils/http.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }
  return jsonResponse({'live': true});
}
