import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }

  final flow = context.request.uri.queryParameters['flow']?.trim() ?? 'login';
  // A public per-account cooldown lookup leaks whether and when an account is
  // active. Keep the endpoint response-compatible without querying identity
  // state; the code-sending endpoint remains the authority for Retry-After.
  return jsonResponse({'flow': flow, 'retry_after': 0, 'cooling_down': false});
}
