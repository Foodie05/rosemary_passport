import 'package:dart_frog/dart_frog.dart';

import '../models/authenticated_user.dart';
import '../repositories/user_repository.dart';
import '../services/token_validation_service.dart';
import '../utils/auth_cookie.dart';
import '../utils/http.dart';

Future<AuthenticatedUser?> currentUser(RequestContext context) async {
  final auth = context.request.headers['authorization'];
  String? token;
  if (auth != null && auth.startsWith('Bearer ')) {
    token = auth.substring('Bearer '.length).trim();
  } else {
    token = readCookieValue(
      context.request.headers['cookie'],
      kAccessTokenCookieName,
    );
  }
  if (token == null || token.isEmpty) {
    return null;
  }
  final verified = await context
      .read<TokenValidationService>()
      .verifyActiveAccessToken(token);
  if (verified == null) {
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
      return handler(context.provide<AuthenticatedUser>(() => user));
    };
  };
}

Middleware requireAdmin() {
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
