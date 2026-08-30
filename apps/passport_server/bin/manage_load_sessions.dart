import 'dart:convert';
import 'dart:io';

import '../lib/src/bootstrap.dart';

Future<void> main() async {
  final action = (Platform.environment['LOAD_TEST_ACTION'] ?? 'generate')
      .trim();
  final outputPath = (Platform.environment['LOAD_TEST_SESSION_FILE'] ?? '')
      .trim();
  if (Platform.environment['ALLOW_LOAD_SESSION_MANAGEMENT'] != 'true' ||
      outputPath.isEmpty ||
      !File(outputPath).isAbsolute) {
    stderr.writeln(
      'Set ALLOW_LOAD_SESSION_MANAGEMENT=true and an absolute '
      'LOAD_TEST_SESSION_FILE path.',
    );
    exitCode = 64;
    return;
  }

  final services = AppServices.instance;
  _requireLocalEnvironment(
    services.config.serverBaseUrl,
    services.config.dbHost,
  );
  await services.start();
  try {
    switch (action) {
      case 'generate':
        await _generate(services, File(outputPath));
      case 'revoke':
        await _revoke(services, File(outputPath));
      default:
        throw ArgumentError.value(
          action,
          'LOAD_TEST_ACTION',
          'generate or revoke',
        );
    }
  } finally {
    await services.close();
  }
}

Future<void> _generate(AppServices services, File output) async {
  final count = int.tryParse(
    (Platform.environment['LOAD_TEST_SESSION_COUNT'] ?? '').trim(),
  );
  final email = (Platform.environment['LOAD_TEST_USER_EMAIL'] ?? '').trim();
  if (count == null || count < 1 || count > 5000 || email.isEmpty) {
    throw ArgumentError(
      'LOAD_TEST_SESSION_COUNT must be 1..5000 and LOAD_TEST_USER_EMAIL is required.',
    );
  }
  if (output.existsSync() &&
      Platform.environment['LOAD_TEST_OVERWRITE'] != 'true') {
    throw StateError(
      'Session file already exists; explicit overwrite is required.',
    );
  }

  final user = await services.userRepository.findByEmail(email);
  if (user == null) {
    throw StateError('The selected load-test user does not exist.');
  }

  final sessions = <Map<String, String>>[];
  for (var index = 0; index < count; index += 1) {
    final pair = services.tokenService.issueTokenPair(
      user.toAuthenticatedUser(),
      refreshTokenTtlSeconds: services.tokenService
          .firstPartyRefreshTokenTtlSeconds(rememberMe: false),
    );
    final now = DateTime.now().toUtc();
    await services.oidcRepository.storeTokenPair(
      accessTokenId: pair.accessTokenId,
      refreshTokenId: pair.refreshTokenId,
      familyId: pair.familyId,
      userId: user.id,
      clientId: 'first_party_web',
      accessExpiresAt: now.add(Duration(seconds: pair.expiresIn)),
      refreshExpiresAt: now.add(Duration(seconds: pair.refreshExpiresIn)),
    );
    sessions.add({
      'access_token': pair.accessToken,
      'refresh_token': pair.refreshToken,
      'family_id': pair.familyId,
    });
  }

  await output.writeAsString(jsonEncode(sessions), flush: true);
  final chmod = await Process.run('chmod', ['0600', output.path]);
  if (chmod.exitCode != 0) {
    await output.delete();
    throw StateError('Could not restrict the session file to mode 0600.');
  }
  stdout.writeln('Generated $count isolated load-test sessions.');
}

Future<void> _revoke(AppServices services, File input) async {
  if (!input.existsSync()) {
    throw StateError('Session file does not exist.');
  }
  final decoded = jsonDecode(await input.readAsString());
  if (decoded is! List) {
    throw const FormatException('Session file must contain a JSON array.');
  }
  final familyIds = decoded
      .map((entry) => entry is Map ? entry['family_id']?.toString() : null)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet();
  if (familyIds.length != decoded.length) {
    throw const FormatException(
      'Every session must have a distinct family_id.',
    );
  }
  for (final familyId in familyIds) {
    await services.oidcRepository.revokeTokenFamily(familyId);
  }
  stdout.writeln('Revoked ${familyIds.length} load-test token families.');
}

void _requireLocalEnvironment(String serverBaseUrl, String dbHost) {
  final serverHost = Uri.tryParse(serverBaseUrl)?.host.toLowerCase() ?? '';
  const localHosts = {'localhost', '127.0.0.1', '::1'};
  if (!localHosts.contains(serverHost) ||
      !localHosts.contains(dbHost.toLowerCase())) {
    throw StateError(
      'Load-session management is restricted to local environments.',
    );
  }
}
