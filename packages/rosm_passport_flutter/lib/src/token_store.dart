import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

abstract interface class RosmTokenStore {
  Future<void> save(RosmTokenSet tokens);

  Future<RosmTokenSet?> read();

  Future<void> clear();
}

class RosmSecureTokenStore implements RosmTokenStore {
  RosmSecureTokenStore({
    FlutterSecureStorage? storage,
    this.prefix = 'rosm_passport',
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String prefix;

  @override
  Future<void> save(RosmTokenSet tokens) async {
    for (final entry in tokens.toStorageJson().entries) {
      await _storage.write(key: '$prefix.${entry.key}', value: entry.value);
    }
  }

  @override
  Future<RosmTokenSet?> read() async {
    final accessToken = await _storage.read(key: '$prefix.access_token');
    final refreshToken = await _storage.read(key: '$prefix.refresh_token');
    final expiresIn = await _storage.read(key: '$prefix.expires_in');
    if (accessToken == null || refreshToken == null || expiresIn == null) {
      return null;
    }
    return RosmTokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: await _storage.read(key: '$prefix.token_type') ?? 'Bearer',
      expiresIn: int.tryParse(expiresIn) ?? 0,
      idToken: await _storage.read(key: '$prefix.id_token'),
    );
  }

  @override
  Future<void> clear() async {
    for (final key in const [
      'access_token',
      'refresh_token',
      'token_type',
      'expires_in',
      'id_token',
    ]) {
      await _storage.delete(key: '$prefix.$key');
    }
  }
}

class RosmMemoryTokenStore implements RosmTokenStore {
  RosmTokenSet? _tokens;

  @override
  Future<void> save(RosmTokenSet tokens) async {
    _tokens = tokens;
  }

  @override
  Future<RosmTokenSet?> read() async => _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
