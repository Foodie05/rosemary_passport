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
    if (redirectUris.any((uri) => !_isAllowedRedirectUri(uri))) {
      throw ArgumentError(
        'redirect_uris must use https or loopback http origins.',
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

  bool _isAllowedRedirectUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    if (uri.scheme == 'https') {
      return true;
    }
    final isLoopbackHost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    return uri.scheme == 'http' && isLoopbackHost;
  }
}
