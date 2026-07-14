import '../repositories/oidc_repository.dart';
import '../security/password_hasher.dart';

class OidcAdminService {
  OidcAdminService(this._repository, this._passwordHasher);

  final OidcRepository _repository;
  final PasswordHasher _passwordHasher;

  Future<List<Map<String, dynamic>>> listClients() {
    return _repository.listClients();
  }

  Future<void> upsertClient({
    required String clientId,
    required String? displayName,
    required bool isOfficial,
    required List<String> redirectUris,
    required List<String> scopes,
    required List<String> grantTypes,
    required bool isConfidential,
    required bool isActive,
    String? clientSecret,
  }) async {
    if (redirectUris.any(
      (uri) => !_isAllowedRedirectUri(uri, isConfidential: isConfidential),
    )) {
      throw ArgumentError(
        isConfidential
            ? 'confidential redirect_uris must use https or loopback http origins.'
            : 'public redirect_uris must use https, loopback http, or a mobile custom scheme such as com.example.app:/oidc/callback.',
      );
    }
    final existing = await _repository.findClient(clientId);
    final trimmedSecret = clientSecret?.trim() ?? '';
    String? secretHash;
    if (trimmedSecret.isNotEmpty) {
      secretHash = await _passwordHasher.hash(trimmedSecret);
    }

    final hasExistingSecret =
        (existing?['client_secret_hash'] as String?)?.trim().isNotEmpty == true;
    if (isConfidential && secretHash == null && !hasExistingSecret) {
      throw ArgumentError('Confidential client requires a client_secret.');
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
