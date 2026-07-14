import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/authenticated_user.dart';
import '../repositories/oidc_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/token_service.dart';
import 'auth_service.dart';
import 'security_policy_service.dart';
import 'security_service.dart';
import 'token_validation_service.dart';

class OidcService {
  OidcService({
    required AppConfig config,
    required OidcRepository oidcRepository,
    required UserRepository userRepository,
    required TokenService tokenService,
    required TokenValidationService tokenValidationService,
    required PasswordHasher passwordHasher,
    required AuthService authService,
    SecurityService? securityService,
    SecurityPolicyService? securityPolicyService,
  }) : _config = config,
       _oidcRepository = oidcRepository,
       _users = userRepository,
       _tokenService = tokenService,
       _tokenValidation = tokenValidationService,
       _passwordHasher = passwordHasher,
       _authService = authService,
       _security = securityService,
       _policy = securityPolicyService;

  final AppConfig _config;
  final OidcRepository _oidcRepository;
  final UserRepository _users;
  final TokenService _tokenService;
  final TokenValidationService _tokenValidation;
  final PasswordHasher _passwordHasher;
  final AuthService _authService;
  final SecurityService? _security;
  final SecurityPolicyService? _policy;
  final _uuid = const Uuid();

  Map<String, dynamic> discoveryDocument() {
    return {
      'issuer': _config.serverBaseUrl,
      'authorization_endpoint': '${_config.serverBaseUrl}/oidc/authorize',
      'token_endpoint': '${_config.serverBaseUrl}/oidc/token',
      'userinfo_endpoint': '${_config.serverBaseUrl}/oidc/userinfo',
      'jwks_uri': '${_config.serverBaseUrl}/oidc/jwks',
      'response_types_supported': ['code'],
      'subject_types_supported': ['public'],
      'id_token_signing_alg_values_supported': ['RS256'],
      'token_endpoint_auth_methods_supported': ['client_secret_post', 'none'],
      'code_challenge_methods_supported': ['S256'],
      'grant_types_supported': ['authorization_code', 'refresh_token'],
      'scopes_supported': [
        'openid',
        'profile',
        'email',
        'phone',
        'accountRule',
      ],
      'revocation_endpoint': '${_config.serverBaseUrl}/oidc/revoke',
      'introspection_endpoint': '${_config.serverBaseUrl}/oidc/introspect',
    };
  }

  Future<Map<String, dynamic>?> findClient(String clientId) {
    return _oidcRepository.findClient(clientId);
  }

  Future<String?> authorize({
    required String clientId,
    required String redirectUri,
    required String responseType,
    required String scope,
    required AuthenticatedUser user,
    required String? nonce,
    String? codeChallenge,
    String? codeChallengeMethod,
  }) async {
    if (responseType != 'code') {
      return null;
    }
    final client = await _oidcRepository.findClient(clientId);
    if (client == null) {
      return null;
    }

    final redirectUris = (client['redirect_uris'] as List<String>);
    final grantTypes = (client['grant_types'] as List<String>).toSet();
    if (!redirectUris.contains(redirectUri)) {
      return null;
    }
    if (!grantTypes.contains('authorization_code')) {
      return null;
    }

    if (_config.oidcRequirePkce &&
        (codeChallenge == null || codeChallengeMethod != 'S256')) {
      return null;
    }

    final requestedScopes = scope.split(' ').where((e) => e.isNotEmpty).toSet();
    final allowedScopes = (client['scopes'] as List<String>).toSet();
    if (!requestedScopes.every(allowedScopes.contains)) {
      return null;
    }
    if (requestedScopes.contains('openid') &&
        (nonce == null || nonce.trim().isEmpty)) {
      return null;
    }

    final code = _uuid.v4();
    await _oidcRepository.storeAuthCode(
      code: code,
      clientId: clientId,
      userId: user.id,
      redirectUri: redirectUri,
      scopes: requestedScopes.toList(),
      nonce: nonce,
      codeChallenge: codeChallenge,
      codeChallengeMethod: codeChallengeMethod,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );

    return code;
  }

  Future<Map<String, dynamic>?> exchangeCode({
    required String code,
    required String clientId,
    required String redirectUri,
    required String? clientSecret,
    required String? codeVerifier,
  }) async {
    final client = await _oidcRepository.findClient(clientId);
    if (client == null) {
      return null;
    }

    final isConfidential = client['is_confidential'] as bool;
    final grantTypes = (client['grant_types'] as List<String>).toSet();
    if (!grantTypes.contains('authorization_code')) {
      return null;
    }
    final secretHash = client['client_secret_hash'] as String?;
    if (isConfidential) {
      if (clientSecret == null || secretHash == null) {
        return null;
      }
      final validSecret = await _passwordHasher.verify(
        secretHash,
        clientSecret,
      );
      if (!validSecret) {
        return null;
      }
    }

    final authCode = await _oidcRepository.consumeAuthCode(code);
    if (authCode == null) {
      return null;
    }

    if (authCode['client_id'] != clientId ||
        authCode['redirect_uri'] != redirectUri) {
      return null;
    }

    final challenge = authCode['code_challenge'] as String?;
    if (_config.oidcRequirePkce || challenge != null) {
      if (codeVerifier == null) {
        return null;
      }
      final digest = sha256.convert(utf8.encode(codeVerifier)).bytes;
      final expectedChallenge = base64Url.encode(digest).replaceAll('=', '');
      if (expectedChallenge != challenge) {
        return null;
      }
    }

    final user = await _users.findById(authCode['user_id'] as String);
    if (user == null) {
      return null;
    }

    final tokens = _tokenService.issueTokenPair(
      user.toAuthenticatedUser(),
      scopes: (authCode['scopes'] as List<String>),
      clientId: clientId,
      nonce: authCode['nonce'] as String?,
    );
    await _oidcRepository.storeAccessToken(
      tokenId: tokens.accessTokenId,
      userId: user.id,
      clientId: clientId,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: _config.accessTokenTtlSeconds),
      ),
    );
    await _oidcRepository.storeRefreshToken(
      tokenId: tokens.refreshTokenId,
      userId: user.id,
      clientId: clientId,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: _config.refreshTokenTtlSeconds),
      ),
    );

    return tokens.toJson();
  }

  Future<Map<String, dynamic>?> userInfo(String accessToken) async {
    final verified = await _tokenValidation.verifyActiveAccessToken(
      accessToken,
    );
    if (verified == null) {
      return null;
    }

    final payload = verified.payload;
    final userId = payload['sub'] as String?;
    if (userId == null) {
      return null;
    }
    final user = await _users.findById(userId);
    if (user == null) {
      return null;
    }
    final scopes = (payload['scope'] as String? ?? '')
        .split(' ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    return {
      'sub': user.id,
      if (scopes.contains('email')) 'email': user.email,
      if (scopes.contains('email')) 'email_verified': user.isEmailVerified,
      if (scopes.contains('phone') &&
          (user.phoneNumber ?? '').trim().isNotEmpty)
        'phone_number': user.phoneNumber,
      if (scopes.contains('phone') &&
          (user.phoneNumber ?? '').trim().isNotEmpty)
        'phone_number_verified': user.isPhoneVerified,
      if (scopes.contains('profile')) 'name': user.nickname,
      if (scopes.contains('profile')) 'nickname': user.nickname,
      if (scopes.contains('accountRule')) 'roles': user.roles,
    };
  }

  Future<Map<String, dynamic>?> introspect({
    required String token,
    required String clientId,
    required String? clientSecret,
    String? requestIp,
  }) async {
    final security = _security;
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final client = await _authenticateConfidentialClient(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    if (client == null) {
      return null;
    }

    if (requestIp != null && requestIp.trim().isNotEmpty) {
      if (security == null) {
        return {'active': false};
      }
      final decision = await security.enforce(
        scope: 'oidc:introspect:$clientId:ip',
        subject: requestIp.trim(),
        limit: policy.oidcIntrospectIpLimit,
        window: Duration(seconds: policy.oidcIntrospectWindowSeconds),
        blockDuration: Duration(seconds: policy.oidcIntrospectBlockSeconds),
      );
      if (!decision.allowed) {
        return null;
      }
    }

    final access = await _tokenValidation.verifyActiveAccessToken(token);
    if (access != null) {
      final payload = access.payload;
      if (payload['client_id'] != clientId) {
        return {'active': false};
      }
      return {
        'active': true,
        'sub': payload['sub'],
        'scope': payload['scope'],
        'token_type': 'access_token',
      };
    }

    final refresh = await _tokenValidation.verifyActiveRefreshToken(token);
    if (refresh == null) {
      return {'active': false};
    }

    final tokenId = refresh.payload['jti'] as String?;
    if (refresh.payload['client_id'] != clientId) {
      return {'active': false};
    }
    if (tokenId == null) {
      return {'active': false};
    }

    return {
      'active': true,
      'sub': refresh.payload['sub'],
      'token_type': 'refresh_token',
    };
  }

  Future<bool> revoke({
    required String token,
    required String clientId,
    required String? clientSecret,
  }) async {
    final client = await _authenticateClient(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    if (client == null) {
      return false;
    }

    final access = await _tokenValidation.verifyActiveAccessToken(token);
    if (access != null) {
      final tokenId = access.payload['jti'] as String?;
      if (access.payload['client_id'] != clientId || tokenId == null) {
        return false;
      }
      final accessRecord = await _oidcRepository.findAccessToken(tokenId);
      if (accessRecord == null ||
          accessRecord['client_id'] != clientId ||
          (accessRecord['revoked_at'] as DateTime?) != null) {
        return false;
      }
      await _oidcRepository.revokeAccessToken(tokenId);
      return true;
    }

    final refresh = await _tokenValidation.verifyActiveRefreshToken(token);
    if (refresh == null) {
      return false;
    }

    final tokenId = refresh.payload['jti'] as String?;
    if (refresh.payload['client_id'] != clientId) {
      return false;
    }
    if (tokenId == null) {
      return false;
    }

    final refreshRecord = await _oidcRepository.findRefreshToken(tokenId);
    if (refreshRecord == null ||
        refreshRecord['client_id'] != clientId ||
        (refreshRecord['revoked_at'] as DateTime?) != null) {
      return false;
    }

    await _oidcRepository.revokeRefreshToken(tokenId);
    return true;
  }

  Future<Map<String, dynamic>?> refreshTokenGrant({
    required String refreshToken,
    required String clientId,
    required String? clientSecret,
    String? requestIp,
  }) async {
    final security = _security;
    final policy = _policy == null
        ? SecurityPolicyService.defaultPolicy
        : await _policy.load();
    final client = await _authenticateClient(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    if (client == null) {
      return null;
    }

    if (requestIp != null && requestIp.trim().isNotEmpty) {
      if (security == null) {
        return null;
      }
      final decision = await security.enforce(
        scope: 'oidc:token:$clientId:ip',
        subject: requestIp.trim(),
        limit: policy.oidcTokenIpLimit,
        window: Duration(seconds: policy.oidcTokenWindowSeconds),
        blockDuration: Duration(seconds: policy.oidcTokenBlockSeconds),
      );
      if (!decision.allowed) {
        return null;
      }
    }

    final pair = await _authService.refreshForClient(
      refreshToken,
      clientId: clientId,
      requestIp: requestIp,
    );
    return pair?.toJson();
  }

  Future<bool> authenticateControlClient({
    required String clientId,
    required String? clientSecret,
  }) async {
    final client = await _authenticateConfidentialClient(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    return client != null;
  }

  Future<bool> authenticateRevocationClient({
    required String clientId,
    required String? clientSecret,
  }) async {
    final client = await _authenticateClient(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    return client != null;
  }

  Future<Map<String, dynamic>?> _authenticateClient({
    required String clientId,
    required String? clientSecret,
  }) async {
    final client = await _oidcRepository.findClient(clientId);
    if (client == null) {
      return null;
    }

    final isConfidential = client['is_confidential'] as bool;
    final secretHash = client['client_secret_hash'] as String?;
    if (!isConfidential) {
      return client;
    }
    if (clientSecret == null || clientSecret.isEmpty || secretHash == null) {
      return null;
    }
    final validSecret = await _passwordHasher.verify(secretHash, clientSecret);
    return validSecret ? client : null;
  }

  Future<Map<String, dynamic>?> _authenticateConfidentialClient({
    required String clientId,
    required String? clientSecret,
  }) async {
    final client = await _oidcRepository.findClient(clientId);
    if (client == null || client['is_confidential'] != true) {
      return null;
    }

    final secretHash = client['client_secret_hash'] as String?;
    if (clientSecret == null || clientSecret.isEmpty || secretHash == null) {
      return null;
    }

    final validSecret = await _passwordHasher.verify(secretHash, clientSecret);
    return validSecret ? client : null;
  }
}
