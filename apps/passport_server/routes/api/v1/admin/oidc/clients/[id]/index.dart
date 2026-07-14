import 'package:dart_frog/dart_frog.dart';

import '../../../../../../../lib/src/services/oidc_admin_service.dart';
import '../../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.delete) {
    final deleted = await context.read<OidcAdminService>().deleteClient(
      id.trim(),
    );
    if (!deleted) {
      return errorResponse('not_found', 'client not found.', statusCode: 404);
    }
    return jsonResponse({'deleted': true});
  }

  if (context.request.method != HttpMethod.put) {
    return errorResponse(
      'method_not_allowed',
      'Use PUT or DELETE.',
      statusCode: 405,
    );
  }

  final body = await tryParseJsonObject(context.request);
  if (body == null) {
    return errorResponse(
      'invalid_request',
      'Request body must be a JSON object.',
    );
  }
  final redirectUris = _readStringList(body['redirect_uris']);
  final scopes = _readStringList(
    body['scopes'],
    fallback: const ['openid', 'profile', 'email', 'phone'],
  );
  final grantTypes = _readStringList(
    body['grant_types'],
    fallback: const ['authorization_code', 'refresh_token'],
  );
  final isConfidential = body['is_confidential'] == true;
  final isActive = body['is_active'] != false;
  final isOfficial = body['is_official'] == true;
  final clientSecret = body['client_secret']?.toString();
  final displayName = body['display_name']?.toString();

  if (id.trim().isEmpty || redirectUris.isEmpty) {
    return errorResponse(
      'invalid_request',
      'client id and redirect_uris are required.',
    );
  }

  try {
    await context.read<OidcAdminService>().upsertClient(
      clientId: id.trim(),
      displayName: displayName,
      isOfficial: isOfficial,
      redirectUris: redirectUris,
      scopes: scopes,
      grantTypes: grantTypes,
      isConfidential: isConfidential,
      isActive: isActive,
      clientSecret: clientSecret,
    );
  } on ArgumentError catch (e) {
    return errorResponse('invalid_request', e.message.toString());
  }

  return jsonResponse({'updated': true});
}

List<String> _readStringList(dynamic raw, {List<String> fallback = const []}) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
  return fallback;
}
