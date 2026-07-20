import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../repositories/webauthn_repository.dart';

class WebAuthnService {
  WebAuthnService({
    required AppConfig config,
    required WebAuthnRepository repository,
  }) : _config = config,
       _repository = repository;

  final AppConfig _config;
  final WebAuthnRepository _repository;

  Future<bool> hasCredentials(String userId) async {
    final credentials = await _repository.listCredentialsForUser(userId);
    return credentials.isNotEmpty;
  }

  Future<int> countCredentials(String userId) {
    return _repository.countCredentialsForUser(userId);
  }

  Future<List<Map<String, dynamic>>> listCredentials(String userId) async {
    final credentials = await _repository.listCredentialsForUser(userId);
    return credentials
        .map(
          (credential) => {
            'credential_id': credential.credentialId,
            'device_type': credential.deviceType,
            'backed_up': credential.backedUp,
            'transports': credential.transports,
            'created_at': credential.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  Future<void> deleteCredential({
    required String userId,
    required String credentialId,
  }) {
    return _repository.deleteCredential(
      userId: userId,
      credentialId: credentialId,
    );
  }

  Future<WebAuthnCredentialRecord?> findCredential(String credentialId) {
    return _repository.findCredential(credentialId);
  }

  Future<Map<String, dynamic>> generateRegistrationOptions({
    required String userId,
    required String email,
    required String nickname,
    required String origin,
  }) async {
    final rpId = _rpIdFromOrigin(origin);
    final credentials = await _repository.listCredentialsForUser(userId);
    final payload = await _runHelper('webauthn-register-options.mjs', {
      'rpName': 'ROSM Pass',
      'rpID': rpId,
      'userID': userId,
      'userName': email,
      'userDisplayName': nickname,
      'excludeCredentials': credentials
          .map(
            (credential) => {
              'id': credential.credentialId,
              'type': 'public-key',
              'transports': credential.transports,
            },
          )
          .toList(),
    });

    final challenge = payload['challenge']?.toString() ?? '';
    await _repository.storeChallenge(
      userId: userId,
      purpose: 'register',
      challenge: challenge,
      rpId: rpId,
      origin: origin,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    return payload;
  }

  Future<bool> verifyRegistration({
    required String userId,
    required Map<String, dynamic> response,
  }) async {
    final challenge = await _repository.findLatestChallenge(
      userId: userId,
      purpose: 'register',
    );
    if (challenge == null ||
        challenge.expiresAt.isBefore(DateTime.now().toUtc())) {
      return false;
    }

    final payload = await _runHelper('webauthn-verify-registration.mjs', {
      'response': response,
      'expectedChallenge': challenge.challenge,
      'expectedOrigin': _expectedOrigins(challenge.origin),
      'expectedRPID': challenge.rpId,
    });

    final verified = payload['verified'] == true;
    if (!verified) {
      return false;
    }

    final registrationInfo = Map<String, dynamic>.from(
      payload['registrationInfo'] as Map? ?? const {},
    );
    await _repository.insertCredential(
      userId: userId,
      credentialId: registrationInfo['credentialID'].toString(),
      publicKey: registrationInfo['credentialPublicKey'].toString(),
      counter: int.tryParse('${registrationInfo['counter']}') ?? 0,
      transports: (registrationInfo['transports'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      deviceType: registrationInfo['deviceType']?.toString(),
      backedUp: registrationInfo['backedUp'] == true,
    );
    await _repository.deleteChallenge(challenge.id);
    return true;
  }

  Future<Map<String, dynamic>?> generateAuthenticationOptions({
    String? email,
    required String origin,
    String? userId,
  }) async {
    final credentials = userId == null
        ? const <WebAuthnCredentialRecord>[]
        : await _repository.listCredentialsForUser(userId);
    if (userId != null && credentials.isEmpty) {
      return null;
    }
    final rpId = _rpIdFromOrigin(origin);
    final payload = await _runHelper('webauthn-auth-options.mjs', {
      'rpID': rpId,
      if (credentials.isNotEmpty)
        'allowCredentials': credentials
            .map(
              (credential) => {
                'id': credential.credentialId,
                'type': 'public-key',
                'transports': credential.transports,
              },
            )
            .toList(),
    });

    final challenge = payload['challenge']?.toString() ?? '';
    await _repository.storeChallenge(
      userId: userId,
      email: email,
      purpose: userId == null ? 'authenticate_discoverable' : 'authenticate',
      challenge: challenge,
      rpId: rpId,
      origin: origin,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    return payload;
  }

  Future<bool> verifyAuthentication({
    String? userId,
    String? email,
    required Map<String, dynamic> response,
  }) async {
    final credentialId = ((response['id'] ?? response['rawId']) ?? '')
        .toString();
    if (credentialId.isEmpty) {
      return false;
    }

    final credential = await _repository.findCredential(credentialId);
    if (credential == null) {
      return false;
    }

    final resolvedUserId = userId ?? credential.userId;
    final challenge = await _repository.findLatestChallenge(
      userId: userId == null ? null : resolvedUserId,
      email: email,
      purpose: userId == null ? 'authenticate_discoverable' : 'authenticate',
    );
    if (challenge == null ||
        challenge.expiresAt.isBefore(DateTime.now().toUtc())) {
      return false;
    }

    final payload = await _runHelper('webauthn-verify-authentication.mjs', {
      'response': response,
      'expectedChallenge': challenge.challenge,
      'expectedOrigin': _expectedOrigins(challenge.origin),
      'expectedRPID': challenge.rpId,
      'credential': {
        'id': credential.credentialId,
        'publicKey': credential.publicKey,
        'counter': credential.counter,
        'transports': credential.transports,
      },
    });

    final verified = payload['verified'] == true;
    if (!verified) {
      return false;
    }

    final authenticationInfo = Map<String, dynamic>.from(
      payload['authenticationInfo'] as Map? ?? const {},
    );
    await _repository.updateCredentialCounter(
      credentialId: credential.credentialId,
      counter:
          int.tryParse('${authenticationInfo['newCounter']}') ??
          credential.counter,
    );
    await _repository.deleteChallenge(challenge.id);
    return true;
  }

  Future<Map<String, dynamic>> _runHelper(
    String scriptName,
    Map<String, dynamic> payload,
  ) async {
    final process = await Process.start('node', [
      'scripts/$scriptName',
    ], workingDirectory: _helperWorkingDirectory);
    process.stdin.writeln(jsonEncode(payload));
    await process.stdin.close();

    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw StateError('WebAuthn helper failed: $stderr');
    }

    return Map<String, dynamic>.from(jsonDecode(stdout) as Map);
  }

  String get _helperWorkingDirectory => '${Directory.current.path}';

  String _rpIdFromOrigin(String origin) {
    try {
      final uri = Uri.parse(origin);
      return uri.host;
    } catch (_) {
      final fallback = Uri.parse(_config.serverBaseUrl);
      return fallback.host;
    }
  }

  List<String> _expectedOrigins(String origin) {
    return <String>{
      origin,
      ..._config.webAuthnAndroidOrigins,
    }.toList(growable: false);
  }
}
