import '../repositories/oidc_repository.dart';
import '../security/token_service.dart';

class TokenValidationService {
  TokenValidationService(this._tokens, this._oidcRepository);

  final TokenService _tokens;
  final OidcRepository _oidcRepository;

  Future<VerifiedToken?> verifyActiveAccessToken(String token) async {
    final verified = _tokens.verify(token, expectedType: 'access');
    if (verified == null) {
      return null;
    }
    final tokenId = verified.payload['jti'] as String?;
    if (tokenId == null) {
      return null;
    }
    final active = await _oidcRepository.isAccessTokenActive(tokenId);
    return active ? verified : null;
  }

  Future<VerifiedToken?> verifyActiveRefreshToken(String token) async {
    final verified = _tokens.verify(token, expectedType: 'refresh');
    if (verified == null) {
      return null;
    }
    final tokenId = verified.payload['jti'] as String?;
    if (tokenId == null) {
      return null;
    }
    final active = await _oidcRepository.isRefreshTokenActive(tokenId);
    return active ? verified : null;
  }
}
