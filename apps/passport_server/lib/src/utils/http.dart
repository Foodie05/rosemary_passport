import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';

Response jsonResponse(
  Object data, {
  int statusCode = 200,
  Map<String, Object>? headers,
}) {
  return Response(
    statusCode: statusCode,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

bool hasTrustedBrowserOrigin(Request request, AppConfig config) {
  final origin = request.headers['origin']?.trim();
  if (origin == null || origin.isEmpty) {
    return false;
  }
  String? normalized(String value) {
    try {
      return Uri.parse(value).origin;
    } catch (_) {
      return null;
    }
  }

  return origin == normalized(config.webBaseUrl) ||
      origin == normalized(config.serverBaseUrl) ||
      config.corsAllowedOrigins.contains(origin);
}

Response errorResponse(String code, String message, {int statusCode = 400}) {
  return jsonResponse({
    'error': code,
    'message': message,
  }, statusCode: statusCode);
}

Future<Map<String, dynamic>?> tryParseJsonObject(Request request) async {
  try {
    final body = await request.json();
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }
    return null;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on Error {
    return null;
  }
}

Future<Map<String, dynamic>?> tryParseJsonOrFormObject(Request request) async {
  final contentType = request.headers['content-type']?.toLowerCase() ?? '';
  if (contentType.startsWith('application/x-www-form-urlencoded')) {
    try {
      final form = await request.formData();
      return Map<String, dynamic>.from(form.fields);
    } on FormatException {
      return null;
    }
  }
  return tryParseJsonObject(request);
}

Map<String, String?> oauthClientCredentials(
  Request request,
  Map<String, dynamic> body,
) {
  String? basicClientId;
  String? basicClientSecret;
  final authorization = request.headers['authorization'] ?? '';
  if (authorization.startsWith('Basic ')) {
    try {
      final decoded = utf8.decode(
        base64.decode(base64.normalize(authorization.substring(6).trim())),
      );
      final separator = decoded.indexOf(':');
      if (separator >= 0) {
        basicClientId = Uri.decodeComponent(decoded.substring(0, separator));
        basicClientSecret = Uri.decodeComponent(
          decoded.substring(separator + 1),
        );
      }
    } catch (_) {
      // Invalid Basic authentication is handled as missing credentials.
    }
  }
  return {
    'client_id': basicClientId ?? body['client_id']?.toString(),
    'client_secret': basicClientSecret ?? body['client_secret']?.toString(),
  };
}

Future<T?> tryParseJsonModel<T>(
  Request request,
  T Function(Map<String, dynamic> json) fromJson,
) async {
  final body = await tryParseJsonObject(request);
  if (body == null) {
    return null;
  }
  try {
    return fromJson(body);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on Error {
    return null;
  }
}

String? clientIpFromRequest(Request request, {AppConfig? config}) {
  final remote = request.connectionInfo.remoteAddress.address.trim();
  if (config == null || !config.trustProxyHeaders) {
    return remote.isEmpty ? null : remote;
  }
  if (!config.isTrustedProxyAddress(remote)) {
    return remote.isEmpty ? null : remote;
  }
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.trim().isNotEmpty) {
    final first = forwarded.split(',').first.trim();
    if (first.isNotEmpty) {
      return first;
    }
  }
  final realIp = request.headers['x-real-ip']?.trim();
  if (realIp != null && realIp.isNotEmpty) {
    return realIp;
  }
  final cfConnectingIp = request.headers['cf-connecting-ip']?.trim();
  if (cfConnectingIp != null && cfConnectingIp.isNotEmpty) {
    return cfConnectingIp;
  }
  return remote.isEmpty ? null : remote;
}
