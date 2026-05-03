import 'package:dart_frog/dart_frog.dart';

import '../../lib/src/services/oidc_service.dart';
import '../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  final service = context.read<OidcService>();
  return jsonResponse(service.discoveryDocument());
}
