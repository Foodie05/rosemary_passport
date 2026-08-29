import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class HelperClient {
  HelperClient(this._config, [http.Client? client])
    : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;
  var _consecutiveFailures = 0;
  DateTime? _circuitOpenUntil;

  bool get enabled => _config.helperBaseUrl.isNotEmpty;

  Future<Map<String, dynamic>> execute(
    String script,
    Map<String, dynamic> payload,
  ) async {
    if (!enabled) {
      throw StateError('Helper sidecar is not configured.');
    }
    final openUntil = _circuitOpenUntil;
    if (openUntil != null && openUntil.isAfter(DateTime.now().toUtc())) {
      throw StateError('Helper circuit is open.');
    }
    try {
      final response = await _client
          .post(
            Uri.parse('${_config.helperBaseUrl}/v1/execute'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer ${_config.helperSharedKey}',
            },
            body: jsonEncode({'script': script, 'payload': payload}),
          )
          .timeout(Duration(seconds: _config.helperTimeoutSeconds));
      if (response.statusCode != 200) {
        throw StateError('Helper returned ${response.statusCode}.');
      }
      _consecutiveFailures = 0;
      _circuitOpenUntil = null;
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 3) {
        _circuitOpenUntil = DateTime.now().toUtc().add(
          const Duration(seconds: 10),
        );
      }
      rethrow;
    }
  }

  Future<bool> healthCheck() async {
    if (!enabled) {
      return false;
    }
    try {
      final response = await _client
          .get(Uri.parse('${_config.helperBaseUrl}/health'))
          .timeout(Duration(seconds: _config.helperTimeoutSeconds));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}
