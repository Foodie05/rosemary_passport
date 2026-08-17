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

/// The non-secret information needed to make a subsequent sign-in faster.
///
/// This never contains a password, one-time code, token, or device credential.
class RosmLastSignIn {
  const RosmLastSignIn({required this.method, required this.identifier});

  final RosmSignInMethod method;
  final String identifier;
}

enum RosmSignInMethod { phoneCode, emailCode, password }

abstract interface class RosmLastSignInStore {
  Future<void> save(RosmLastSignIn hint);

  Future<RosmLastSignIn?> read();

  Future<void> clear();
}

class RosmSecureLastSignInStore implements RosmLastSignInStore {
  RosmSecureLastSignInStore({
    FlutterSecureStorage? storage,
    this.prefix = 'rosm_passport',
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String prefix;

  @override
  Future<void> save(RosmLastSignIn hint) async {
    await _storage.write(
      key: '$prefix.last_sign_in.method',
      value: hint.method.name,
    );
    await _storage.write(
      key: '$prefix.last_sign_in.identifier',
      value: hint.identifier,
    );
  }

  @override
  Future<RosmLastSignIn?> read() async {
    final method = await _storage.read(key: '$prefix.last_sign_in.method');
    final identifier = await _storage.read(
      key: '$prefix.last_sign_in.identifier',
    );
    if (method == null || identifier == null || identifier.trim().isEmpty)
      return null;
    final parsed = RosmSignInMethod.values.where(
      (value) => value.name == method,
    );
    return parsed.isEmpty
        ? null
        : RosmLastSignIn(method: parsed.first, identifier: identifier);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: '$prefix.last_sign_in.method');
    await _storage.delete(key: '$prefix.last_sign_in.identifier');
  }
}

class RosmMemoryLastSignInStore implements RosmLastSignInStore {
  RosmLastSignIn? _hint;

  @override
  Future<void> clear() async => _hint = null;

  @override
  Future<RosmLastSignIn?> read() async => _hint;

  @override
  Future<void> save(RosmLastSignIn hint) async => _hint = hint;
}
