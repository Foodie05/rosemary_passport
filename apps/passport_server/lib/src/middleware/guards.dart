import 'package:dart_frog/dart_frog.dart';

import '../models/authenticated_user.dart';
import '../repositories/user_repository.dart';
import '../services/token_validation_service.dart';
import '../utils/auth_cookie.dart';
import '../utils/http.dart';

Future<AuthenticatedUser?> currentUser(
  RequestContext context, {
  bool requireFirstParty = false,
}) async {
  final auth = context.request.headers['authorization'];
  final cookieToken = readCookieValue(
    context.request.headers['cookie'],
    kAccessTokenCookieName,
  );
  String? token;
  if (auth != null && auth.startsWith('Bearer ')) {
    token = auth.substring('Bearer '.length).trim();
  } else {
    token = cookieToken;
  }
  if ((token == null || token.isEmpty) &&
      (!requireFirstParty || cookieToken == null || cookieToken.isEmpty)) {
    return null;
  }
  final validator = context.read<TokenValidationService>();
  var verified = token == null || token.isEmpty
      ? null
      : await validator.verifyActiveAccessToken(token);
  if (requireFirstParty &&
      verified?.payload['client_id'] != 'first_party_web' &&
      cookieToken != null &&
      cookieToken.isNotEmpty &&
      cookieToken != token) {
    verified = await validator.verifyActiveAccessToken(cookieToken);
  }
  if (verified == null ||
      (requireFirstParty &&
          verified.payload['client_id'] != 'first_party_web')) {
    return null;
  }

  final userId = verified.payload['sub'] as String?;
  final tokenId = verified.payload['jti'] as String?;
  if (userId == null || tokenId == null) {
    return null;
  }

  DateTime? postRegistrationPasskeyBootstrapUntil;
  final rawBootstrapUntil =
      verified.payload['post_register_passkey_bootstrap_until'];
  if (rawBootstrapUntil is num) {
    postRegistrationPasskeyBootstrapUntil = DateTime.fromMillisecondsSinceEpoch(
      rawBootstrapUntil.toInt() * 1000,
      isUtc: true,
    );
  }

  final userRecord = await context.read<UserRepository>().findById(userId);
  return userRecord?.toAuthenticatedUser(
    accessTokenId: tokenId,
    postRegistrationPasskeyBootstrapUntil:
        postRegistrationPasskeyBootstrapUntil,
  );
}

Middleware requireAuth() {
  return (handler) {
    return (context) async {
      final user = await currentUser(context);
      if (user == null) {
        return errorResponse(
          'unauthorized',
          'Access token is missing or invalid.',
          statusCode: 401,
        );
      }
      if (user.isBanned) {
        return errorResponse(
          'account_banned',
          '该账户已被封禁。如需申诉，请联系 info@rosemaryisland.pro。',
          statusCode: 403,
        );
      }
      return handler(context.provide<AuthenticatedUser>(() => user));
    };
  };
}

Middleware requireAdmin() {
  return (handler) {
    return (context) async {
      final user = await currentUser(context, requireFirstParty: true);
      if (user == null) {
        return errorResponse(
          'unauthorized',
          'Access token is missing or invalid.',
          statusCode: 401,
        );
      }
      if (user.isBanned) {
        return errorResponse(
          'account_banned',
          '该账户已被封禁。如需申诉，请联系 info@rosemaryisland.pro。',
          statusCode: 403,
        );
      }
      if (!user.isAdmin) {
        return errorResponse(
          'forbidden',
          'Admin role required.',
          statusCode: 403,
        );
      }
      return handler(context.provide<AuthenticatedUser>(() => user));
    };
  };
}
