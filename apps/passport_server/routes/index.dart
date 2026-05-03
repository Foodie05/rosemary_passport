import 'package:dart_frog/dart_frog.dart';

import '../lib/src/utils/http.dart';

Response onRequest(RequestContext context) {
  return jsonResponse(
    {
      'name': 'ROSM Passport',
      'service': 'sso',
      'status': 'ok',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    },
  );
}
