import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:jose/jose.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/authenticated_user.dart';

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.accessTokenId,
    required this.refreshTokenId,
    required this.familyId,
    required this.refreshExpiresIn,
    this.idToken,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final String accessTokenId;
  final String refreshTokenId;
  final String familyId;
  final int refreshExpiresIn;
  final String? idToken;

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
    if (idToken != null) 'id_token': idToken,
  };
}

class VerifiedToken {
  const VerifiedToken({required this.payload});

  final Map<String, dynamic> payload;
}

class TokenService {
  TokenService(this._config)
    : _privateKey = RSAPrivateKey(
        _config.jwtActivePrivateKeyPem.replaceAll(r'\\n', '\n'),
      ),
      _publicKeys = _config.jwtPublicKeysPem.map(
        (kid, pem) => MapEntry(kid, RSAPublicKey(pem.replaceAll(r'\\n', '\n'))),
      );

  final AppConfig _config;
  final RSAPrivateKey _privateKey;
  final Map<String, RSAPublicKey> _publicKeys;
  final _uuid = const Uuid();

  int get accessTokenTtlSeconds => _config.accessTokenTtlSeconds;
  int get refreshTokenTtlSeconds => _config.refreshTokenTtlSeconds;

  int firstPartyRefreshTokenTtlSeconds({required bool rememberMe}) => rememberMe
      ? _config.firstPartyRememberedRefreshTokenTtlSeconds
      : _config.firstPartyRefreshTokenTtlSeconds;

  TokenPair issueTokenPair(
    AuthenticatedUser user, {
    List<String> scopes = const ['openid', 'profile', 'email', 'phone'],
    String clientId = 'first_party_web',
    String? nonce,
    Map<String, dynamic> additionalAccessClaims = const {},
    int? refreshTokenTtlSeconds,
    String? familyId,
    bool rememberSession = false,
  }) {
    final resolvedAccessTokenTtlSeconds = _config.accessTokenTtlSeconds;
    final accessJti = _uuid.v4();
    final refreshJti = _uuid.v4();
    final resolvedFamilyId = familyId ?? _uuid.v4();
    final resolvedRefreshTokenTtlSeconds =
        refreshTokenTtlSeconds ?? _config.refreshTokenTtlSeconds;

    final accessClaims = <String, dynamic>{
      'sub': user.id,
      'scope': scopes.join(' '),
      'client_id': clientId,
      'jti': accessJti,
      'typ': 'access',
      'sid': resolvedFamilyId,
      'sig2': _secondFactorDigest(subject: user.id, jti: accessJti),
      ...additionalAccessClaims,
    };

    final refreshClaims = <String, dynamic>{
      'sub': user.id,
      'client_id': clientId,
      'jti': refreshJti,
      'typ': 'refresh',
      'sid': resolvedFamilyId,
      'remember': rememberSession,
      'sig2': _secondFactorDigest(subject: user.id, jti: refreshJti),
    };

    final access =
        JWT(
          accessClaims,
          issuer: _config.jwtIssuer,
          audience: Audience([_config.jwtAudience]),
          header: {'kid': _config.jwtActiveKid},
        ).sign(
          _privateKey,
          algorithm: JWTAlgorithm.RS256,
          expiresIn: Duration(seconds: resolvedAccessTokenTtlSeconds),
        );

    final refresh =
        JWT(
          refreshClaims,
          issuer: _config.jwtIssuer,
          audience: Audience([_config.jwtAudience]),
          header: {'kid': _config.jwtActiveKid},
        ).sign(
          _privateKey,
          algorithm: JWTAlgorithm.RS256,
          expiresIn: Duration(seconds: resolvedRefreshTokenTtlSeconds),
        );

    String? idToken;
    if (scopes.contains('openid')) {
      idToken =
          JWT(
            {
              'sub': user.id,
              'aud': clientId,
              if (scopes.contains('email')) 'email': user.email,
              if (scopes.contains('profile')) 'name': user.nickname,
              if (scopes.contains('profile')) 'nickname': user.nickname,
              if (scopes.contains('email')) 'email_verified': true,
              if (scopes.contains('phone') &&
                  (user.phoneNumber ?? '').trim().isNotEmpty)
                'phone_number': user.phoneNumber,
              if (scopes.contains('phone') &&
                  (user.phoneNumber ?? '').trim().isNotEmpty)
                'phone_number_verified': user.isPhoneVerified,
              if (nonce != null && nonce.trim().isNotEmpty)
                'nonce': nonce.trim(),
            },
            issuer: _config.serverBaseUrl,
            subject: user.id,
            audience: Audience([clientId]),
            header: {'kid': _config.jwtActiveKid},
          ).sign(
            _privateKey,
            algorithm: JWTAlgorithm.RS256,
            expiresIn: Duration(seconds: resolvedAccessTokenTtlSeconds),
          );
    }

    return TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: resolvedAccessTokenTtlSeconds,
      tokenType: 'Bearer',
      accessTokenId: accessJti,
      refreshTokenId: refreshJti,
      familyId: resolvedFamilyId,
      refreshExpiresIn: resolvedRefreshTokenTtlSeconds,
      idToken: idToken,
    );
  }

  VerifiedToken? verify(String token, {String expectedType = 'access'}) {
    try {
      final decoded = JWT.decode(token);
      final header = decoded.header;
      if (header?['alg'] != 'RS256') {
        return null;
      }
      final kid = header?['kid']?.toString() ?? '';
      final publicKey = _publicKeys[kid];
      if (publicKey == null) {
        return null;
      }
      final jwt = JWT.verify(
        token,
        publicKey,
        audience: Audience.one(_config.jwtAudience),
        issuer: _config.jwtIssuer,
      );

      final payload = Map<String, dynamic>.from(jwt.payload as Map);

      final sub = payload['sub'] as String?;
      final jti = payload['jti'] as String?;
      final typ = payload['typ'] as String?;
      final sig2 = payload['sig2'] as String?;
      if (sub == null || jti == null || typ != expectedType || sig2 == null) {
        return null;
      }

      final expected = _secondFactorDigest(subject: sub, jti: jti);
      if (!_timingSafeEquals(sig2, expected)) {
        return null;
      }

      return VerifiedToken(payload: payload);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> jwkSet() {
    return {
      'keys': _config.jwtPublicKeysPem.entries.map((entry) {
        final jwk = JsonWebKey.fromPem(entry.value.replaceAll(r'\\n', '\n'));
        return {
          ...jwk.toJson(),
          'kid': entry.key,
          'use': 'sig',
          'alg': 'RS256',
        };
      }).toList(),
    };
  }

  String _secondFactorDigest({required String subject, required String jti}) {
    final key = utf8.encode(_config.jwtBindingKey);
    final data = utf8.encode('$subject.$jti');
    final hmac = Hmac(sha256, key);
    return base64Url.encode(hmac.convert(data).bytes);
  }

  bool _timingSafeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
