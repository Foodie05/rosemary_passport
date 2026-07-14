import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';
import '../services/oidc_service.dart';
import 'http.dart';

class NativeAuthorizationRequest {
  const NativeAuthorizationRequest({
    required this.clientId,
    required this.redirectUri,
    required this.responseType,
    required this.scope,
    required this.nonce,
    required this.codeChallenge,
    required this.codeChallengeMethod,
    this.serverHandoff = false,
    this.state,
  });

  final String clientId;
  final String redirectUri;
  final String responseType;
  final String scope;
  final String? nonce;
  final String? codeChallenge;
  final String? codeChallengeMethod;
  final bool serverHandoff;
  final String? state;
}

class NativeAuthorizationDescription {
  const NativeAuthorizationDescription({
    required this.request,
    required this.client,
    required this.requestedScopes,
  });

  final NativeAuthorizationRequest request;
  final Map<String, dynamic> client;
  final Set<String> requestedScopes;

  Map<String, dynamic> toJson() {
    final displayName = (client['display_name'] as String?)?.trim();
    return {
      'authorization_request': {
        'client_id': request.clientId,
        'redirect_uri': request.redirectUri,
        'response_type': request.responseType,
        'scope': request.scope,
        if (request.state != null) 'state': request.state,
        if (request.nonce != null) 'nonce': request.nonce,
        if (request.codeChallenge != null)
          'code_challenge': request.codeChallenge,
        if (request.codeChallengeMethod != null)
          'code_challenge_method': request.codeChallengeMethod,
        if (request.serverHandoff) 'server_handoff': true,
      },
      'client': {
        'client_id': request.clientId,
        'display_name': displayName == null || displayName.isEmpty
            ? request.clientId
            : displayName,
        'is_official': client['is_official'] == true,
        'is_confidential': client['is_confidential'] == true,
      },
      'scopes': requestedScopes.map(scopeDescription).toList(),
      'pkce_required': true,
      'server_handoff': request.serverHandoff,
    };
  }
}

NativeAuthorizationRequest? parseNativeAuthorizationRequest(
  Map<String, dynamic>? body,
) {
  if (body == null) {
    return null;
  }
  final clientId = body['client_id']?.toString().trim();
  final redirectUri = body['redirect_uri']?.toString().trim();
  final responseType = body['response_type']?.toString().trim();
  final rawScope = body['scope']?.toString().trim();
  final codeChallenge = body['code_challenge']?.toString().trim();
  final codeChallengeMethod = body['code_challenge_method']?.toString().trim();

  if (clientId == null ||
      clientId.isEmpty ||
      redirectUri == null ||
      redirectUri.isEmpty ||
      responseType == null ||
      responseType.isEmpty) {
    return null;
  }

  return NativeAuthorizationRequest(
    clientId: clientId,
    redirectUri: redirectUri,
    responseType: responseType,
    scope: rawScope == null || rawScope.isEmpty
        ? 'openid profile email'
        : rawScope,
    state: body['state']?.toString(),
    nonce: body['nonce']?.toString(),
    codeChallenge: codeChallenge == null || codeChallenge.isEmpty
        ? null
        : codeChallenge,
    codeChallengeMethod:
        codeChallengeMethod == null || codeChallengeMethod.isEmpty
        ? null
        : codeChallengeMethod,
    serverHandoff: body['server_handoff'] == true,
  );
}

Future<NativeAuthorizationDescription?> describeNativeAuthorization(
  RequestContext context,
  NativeAuthorizationRequest request,
) async {
  final oidc = context.read<OidcService>();
  final client = await oidc.findClient(request.clientId);
  if (client == null) {
    return null;
  }
  final isConfidential = client['is_confidential'] == true;
  if (isConfidential && !request.serverHandoff) {
    return null;
  }
  if (isConfidential && !_isServerRedirectUri(request.redirectUri)) {
    return null;
  }

  final requestedScopes = request.scope
      .split(' ')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet();
  final allowedScopes = (client['scopes'] as List<String>).toSet();
  final redirectUris = (client['redirect_uris'] as List<String>).toSet();
  final grantTypes = (client['grant_types'] as List<String>).toSet();

  final valid =
      request.responseType == 'code' &&
      redirectUris.contains(request.redirectUri) &&
      grantTypes.contains('authorization_code') &&
      requestedScopes.every(allowedScopes.contains) &&
      (!requestedScopes.contains('openid') ||
          (request.nonce != null && request.nonce!.trim().isNotEmpty)) &&
      request.codeChallenge != null &&
      request.codeChallengeMethod == 'S256';

  if (!valid) {
    return null;
  }

  return NativeAuthorizationDescription(
    request: request,
    client: client,
    requestedScopes: requestedScopes,
  );
}

bool _isServerRedirectUri(String redirectUri) {
  final uri = Uri.tryParse(redirectUri);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return false;
  }
  if (uri.scheme == 'https') {
    return true;
  }
  if (uri.scheme != 'http') {
    return false;
  }
  return uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '::1';
}

Map<String, String> scopeDescription(String scope) {
  return switch (scope) {
    'openid' => {'name': scope, 'description': '确认你的登录身份'},
    'profile' => {'name': scope, 'description': '基础资料（昵称）'},
    'email' => {'name': scope, 'description': '电子邮箱'},
    'phone' => {'name': scope, 'description': '电话号码'},
    'accountRule' => {'name': scope, 'description': '账户角色'},
    _ => {'name': scope, 'description': scope},
  };
}

Response invalidNativeAuthorizationResponse() {
  return errorResponse('invalid_authorization_request', '原生授权请求不完整或客户端配置不正确。');
}

Uri callbackUriFor({
  required String redirectUri,
  String? code,
  String? error,
  String? errorDescription,
  String? state,
}) {
  return Uri.parse(redirectUri).replace(
    queryParameters: {
      ...Uri.parse(redirectUri).queryParameters,
      if (code != null) 'code': code,
      if (error != null) 'error': error,
      if (errorDescription != null) 'error_description': errorDescription,
      if (state != null) 'state': state,
    },
  );
}

String serverBaseUrl(RequestContext context) {
  return context.read<AppConfig>().serverBaseUrl;
}
