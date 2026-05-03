import 'package:dart_frog/dart_frog.dart';

import '../../lib/src/security/token_service.dart';
import '../../lib/src/utils/http.dart';

Response onRequest(RequestContext context) {
  final tokenService = context.read<TokenService>();
  return jsonResponse(tokenService.jwkSet());
}
