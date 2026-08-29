import 'package:dart_frog/dart_frog.dart';

import '../../lib/src/bootstrap.dart';
import '../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }
  final readiness = await AppServices.instance.readiness();
  return jsonResponse(
    readiness,
    statusCode: readiness['ready'] == true ? 200 : 503,
  );
}
