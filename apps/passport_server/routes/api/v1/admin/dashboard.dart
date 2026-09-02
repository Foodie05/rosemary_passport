import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/repositories/admin_analytics_repository.dart';
import '../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('method_not_allowed', 'Use GET.', statusCode: 405);
  }
  final days = int.tryParse(context.request.uri.queryParameters['days'] ?? '');
  return jsonResponse(
    await context.read<AdminAnalyticsRepository>().dashboard(days: days ?? 30),
  );
}
