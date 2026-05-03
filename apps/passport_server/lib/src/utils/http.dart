import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';

Response jsonResponse(
  Object data, {
  int statusCode = 200,
  Map<String, String>? headers,
}) {
  return Response(
    statusCode: statusCode,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
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
