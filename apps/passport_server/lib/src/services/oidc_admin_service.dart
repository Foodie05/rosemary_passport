import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../repositories/oidc_repository.dart';
import '../security/password_hasher.dart';

class OidcClientUpsertResult {
  const OidcClientUpsertResult({this.generatedClientSecret});

  final String? generatedClientSecret;
}

class OidcAdminService {
  OidcAdminService(this._repository, this._passwordHasher);

  final OidcRepository _repository;
  final PasswordHasher _passwordHasher;
  final Random _secureRandom = Random.secure();

  Future<List<Map<String, dynamic>>> listClients() {
    return _repository.listClients();
  }

  Future<OidcClientUpsertResult> upsertClient({
    required String clientId,
    required String? displayName,
    required bool isOfficial,
    required List<String> redirectUris,
    required List<String> scopes,
    required List<String> grantTypes,
    required bool isConfidential,
    required bool isActive,
    String? clientSecret,
    bool generateClientSecret = false,
  }) async {
    if (redirectUris.any(
      (uri) => !_isAllowedRedirectUri(uri, isConfidential: isConfidential),
    )) {
      throw ArgumentError(
        isConfidential
            ? '机密客户端的回调地址必须使用 HTTPS 或本机回环 HTTP，不能使用自定义 scheme。'
            : '回调地址须使用 HTTPS、本机回环 HTTP 或 App 自定义 scheme，且不能包含用户名、密码或 # 片段。',
      );
    }
    final existing = await _repository.findClient(clientId);
    final suppliedSecret = clientSecret?.trim() ?? '';
    final hasExistingSecret =
        (existing?['client_secret_hash'] as String?)?.trim().isNotEmpty == true;
    final shouldGenerateSecret =
        isConfidential &&
        (generateClientSecret ||
            (suppliedSecret.isEmpty && !hasExistingSecret));
    final generatedSecret = shouldGenerateSecret
        ? _generateClientSecret()
        : null;
    final secret = generatedSecret ?? suppliedSecret;
    String? secretHash;
    if (secret.isNotEmpty) {
      secretHash = await _passwordHasher.hash(secret);
    }

    if (isConfidential && secretHash == null && !hasExistingSecret) {
      throw StateError('Unable to generate a client secret.');
    }

    await _repository.upsertClient(
      clientId: clientId,
      displayName: displayName?.trim(),
      isOfficial: isOfficial,
      redirectUris: redirectUris,
      scopes: scopes,
      grantTypes: grantTypes,
      isConfidential: isConfidential,
      isActive: isActive,
      clientSecretHash: secretHash,
    );
    return OidcClientUpsertResult(generatedClientSecret: generatedSecret);
  }

  String _generateClientSecret() {
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => _secureRandom.nextInt(256)),
    );
    return 'rps_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  Future<bool> deleteClient(String clientId) async {
    final existing = await _repository.findClient(clientId);
    if (existing == null) {
      return false;
    }
    await _repository.deleteClient(clientId);
    return true;
  }

  bool _isAllowedRedirectUri(String value, {required bool isConfidential}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        uri.fragment.isNotEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.scheme == 'https') {
      return uri.host.isNotEmpty;
    }
    final isLoopbackHost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme == 'http') {
      return isLoopbackHost;
    }
    if (isConfidential) {
      return false;
    }
    return _isMobileCustomScheme(uri);
  }

  bool _isMobileCustomScheme(Uri uri) {
    const blockedSchemes = {
      'about',
      'data',
      'file',
      'ftp',
      'http',
      'https',
      'javascript',
      'vbscript',
      'mailto',
      'tel',
    };
    final scheme = uri.scheme.toLowerCase();
    if (blockedSchemes.contains(scheme)) {
      return false;
    }
    return uri.path.isNotEmpty || uri.host.isNotEmpty;
  }
}
