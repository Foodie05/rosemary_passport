import 'package:dart_frog/dart_frog.dart';

import '../../../../../../lib/src/services/oidc_admin_service.dart';
import '../../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  final service = context.read<OidcAdminService>();

  if (context.request.method == HttpMethod.get) {
    final clients = await service.listClients();
    return jsonResponse({'clients': clients});
  }

  if (context.request.method == HttpMethod.post) {
    final body = await tryParseJsonObject(context.request);
    if (body == null) {
      return errorResponse(
        'invalid_request',
        'Request body must be a JSON object.',
      );
    }
    final clientId = body['client_id']?.toString().trim() ?? '';
    final redirectUris = _readStringList(
      body['redirect_uris'],
      fallback: const [],
    );
    final scopes = _readStringList(
      body['scopes'],
      fallback: const ['openid', 'profile', 'email'],
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

    if (clientId.isEmpty || redirectUris.isEmpty) {
      return errorResponse(
        'invalid_request',
        'client_id and redirect_uris are required.',
      );
    }

    try {
      await service.upsertClient(
        clientId: clientId,
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

    return jsonResponse({'updated': true}, statusCode: 201);
  }

  return errorResponse(
    'method_not_allowed',
    'Use GET or POST.',
    statusCode: 405,
  );
}

List<String> _readStringList(dynamic raw, {required List<String> fallback}) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
  return fallback;
}
