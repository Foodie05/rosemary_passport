import '../repositories/oidc_repository.dart';
import '../repositories/user_repository.dart';
import '../security/token_service.dart';
import 'audit_service.dart';
import 'auth_attempts.dart';
import 'security_policy_service.dart';
import 'security_service.dart';

/// Owns refresh-token rotation and first-party session revocation.
///
/// Keeping this stateful, security-sensitive lifecycle separate from login and
/// registration makes its transaction and compatibility rules independently
/// testable without changing the public [AuthService] API.
class SessionService {
  static const _postRegistrationPasskeyBootstrapSeconds = 600;

  SessionService({
    required UserRepository userRepository,
    required TokenService tokenService,
    required OidcRepository oidcRepository,
    required AuditService auditService,
    SecurityService? securityService,
    SecurityPolicyService? securityPolicyService,
  }) : _users = userRepository,
       _tokens = tokenService,
       _oidc = oidcRepository,
       _audit = auditService,
       _security = securityService,
       _policy = securityPolicyService;

  final UserRepository _users;
  final TokenService _tokens;
  final OidcRepository _oidc;
  final AuditService _audit;
  final SecurityService? _security;
  final SecurityPolicyService? _policy;

  Future<AuthResult> issueFirstPartyAuthResult(
    UserRecord user, {
    bool postRegistrationPasskeyBootstrap = false,
    bool rememberMe = false,
  }) async {
    // This short-lived claim is only minted on the access token returned by
    // self-registration. Refreshed and later login sessions never receive it.
    final bootstrapUntilEpochSeconds = postRegistrationPasskeyBootstrap
        ? DateTime.now()
                  .toUtc()
                  .add(
                    const Duration(
                      seconds: _postRegistrationPasskeyBootstrapSeconds,
                    ),
                  )
                  .millisecondsSinceEpoch ~/
              1000
        : null;
    final refreshTokenTtlSeconds = _tokens.firstPartyRefreshTokenTtlSeconds(
      rememberMe: rememberMe,
    );
    final tokens = _tokens.issueTokenPair(
      user.toAuthenticatedUser(),
      refreshTokenTtlSeconds: refreshTokenTtlSeconds,
      rememberSession: rememberMe,
      additionalAccessClaims: {
        if (bootstrapUntilEpochSeconds != null)
          'post_register_passkey_bootstrap_until': bootstrapUntilEpochSeconds,
      },
    );
    final now = DateTime.now().toUtc();
    await _oidc.storeTokenPair(
      accessTokenId: tokens.accessTokenId,
      refreshTokenId: tokens.refreshTokenId,
      familyId: tokens.familyId,
      userId: user.id,
      clientId: 'first_party_web',
      accessExpiresAt: now.add(
        Duration(seconds: _tokens.accessTokenTtlSeconds),
      ),
      refreshExpiresAt: now.add(Duration(seconds: refreshTokenTtlSeconds)),
    );
    return AuthResult(
      user: user.toAuthenticatedUser(),
      tokens: tokens,
      postRegistrationPasskeyBootstrap: postRegistrationPasskeyBootstrap,
    );
  }

  Future<void> revokeAllUserSessions(
    String userId, {
    String? preservedAccessTokenId,
  }) {
    return Future.wait([
      _oidc.revokeRefreshTokensForUser(userId),
      if (preservedAccessTokenId == null || preservedAccessTokenId.isEmpty)
        _oidc.revokeAccessTokensForUser(userId)
      else
        _oidc.revokeAccessTokensForUserExcept(userId, preservedAccessTokenId),
    ]);
  }

  Future<TokenPair?> refresh(String refreshToken) {
    return refreshForClient(refreshToken, clientId: 'first_party_web');
  }

  Future<TokenPair?> refreshForClient(
    String refreshToken, {
    required String clientId,
    String? requestIp,
  }) async {
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final security = _security;
    if (security != null &&
        policy.ipRateLimitEnabled &&
        requestIp != null &&
        requestIp.trim().isNotEmpty) {
      final ipDecision = await security.enforce(
        scope: 'refresh:$clientId:ip',
        subject: requestIp.trim(),
        limit: policy.refreshIpLimit,
        window: Duration(seconds: policy.refreshWindowSeconds),
        blockDuration: Duration(seconds: policy.refreshBlockSeconds),
      );
      if (!ipDecision.allowed) {
        return null;
      }
    }

    final verified = _tokens.verify(refreshToken, expectedType: 'refresh');
    if (verified == null) {
      return null;
    }

    final payload = verified.payload;
    final tokenId = payload['jti'] as String?;
    final userId = payload['sub'] as String?;
    final tokenClientId =
        (payload['client_id'] as String?)?.trim().isNotEmpty == true
        ? payload['client_id'] as String
        : 'first_party_web';
    if (tokenId == null || userId == null || tokenClientId != clientId) {
      return null;
    }

    final refreshRecord = await _oidc.findRefreshToken(tokenId);
    if (refreshRecord == null ||
        (refreshRecord['client_id'] as String?) != clientId) {
      return null;
    }
    final familyId = refreshRecord['family_id'] as String?;
    if (familyId == null || familyId.isEmpty) {
      return null;
    }

    final user = await _users.findById(userId);
    if (user == null || user.isBanned) {
      return null;
    }

    final rememberSession = payload['remember'] == true;
    final refreshTtl = clientId == 'first_party_web'
        ? _tokens.firstPartyRefreshTokenTtlSeconds(rememberMe: rememberSession)
        : _tokens.refreshTokenTtlSeconds;
    final pair = _tokens.issueTokenPair(
      user.toAuthenticatedUser(),
      clientId: clientId,
      familyId: familyId,
      refreshTokenTtlSeconds: refreshTtl,
      rememberSession: rememberSession,
    );
    final now = DateTime.now().toUtc();
    final rotation = await _oidc.rotateRefreshToken(
      oldTokenId: tokenId,
      newAccessTokenId: pair.accessTokenId,
      newRefreshTokenId: pair.refreshTokenId,
      familyId: pair.familyId,
      userId: user.id,
      clientId: clientId,
      accessExpiresAt: now.add(
        Duration(seconds: _tokens.accessTokenTtlSeconds),
      ),
      refreshExpiresAt: now.add(Duration(seconds: pair.refreshExpiresIn)),
    );
    if (rotation == RefreshRotationStatus.reused) {
      await _audit.log(
        action: 'session.refresh_reuse_detected',
        actorId: user.id,
        actorType: 'user',
        resourceType: 'token_family',
        resourceId: familyId,
        metadata: {'client_id': clientId},
        ip: requestIp,
      );
    }
    return rotation == RefreshRotationStatus.success ? pair : null;
  }

  Future<void> logoutFirstPartySession({
    String? accessToken,
    String? refreshToken,
    String? requestIp,
  }) async {
    final access = accessToken?.trim() ?? '';
    final refresh = refreshToken?.trim() ?? '';
    final accessVerified = access.isEmpty
        ? null
        : _tokens.verify(access, expectedType: 'access');
    final refreshVerified = refresh.isEmpty
        ? null
        : _tokens.verify(refresh, expectedType: 'refresh');
    final familyId =
        refreshVerified?.payload['sid']?.toString() ??
        accessVerified?.payload['sid']?.toString();
    if (familyId != null && familyId.isNotEmpty) {
      await _oidc.revokeTokenFamily(familyId);
      final userId =
          refreshVerified?.payload['sub']?.toString() ??
          accessVerified?.payload['sub']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await _audit.log(
          action: 'session.logout',
          actorId: userId,
          actorType: 'user',
          resourceType: 'token_family',
          resourceId: familyId,
          metadata: const {},
          ip: requestIp,
        );
      }
      return;
    }
    final tokenId = accessVerified?.payload['jti'] as String?;
    if (tokenId != null) {
      await _oidc.revokeAccessToken(tokenId);
    }
  }
}
