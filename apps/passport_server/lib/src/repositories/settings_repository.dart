import 'dart:convert';

import '../db/database.dart';
import '../security/settings_cipher.dart';

class SettingsRepository {
  SettingsRepository(this._db, this._cipher);

  final Database _db;
  final SettingsCipher _cipher;

  Future<Map<String, dynamic>> getJson(String key) async {
    final result = await _db.execute(
      'select value from system_settings where key = @key',
      params: {'key': key},
    );
    if (result.isEmpty) {
      return {};
    }
    return _cipher.decryptEnvelopes(_toMap(result.first[0]));
  }

  Future<void> upsertJson(String key, Map<String, dynamic> value) async {
    final protectedValue = await _cipher.encryptSensitiveFields(value);
    await _db.execute(
      '''
      insert into system_settings(key, value, updated_at)
      values (@key, @value::jsonb, now())
      on conflict (key)
      do update set value = @value::jsonb, updated_at = now()
      ''',
      params: {'key': key, 'value': jsonEncode(protectedValue)},
    );
  }

  Future<int> migratePlaintextSecrets() async {
    var migrated = 0;
    for (final key in const ['smtp', 'security']) {
      final result = await _db.execute(
        'select value from system_settings where key = @key',
        params: {'key': key},
      );
      if (result.isEmpty) {
        continue;
      }
      final raw = _toMap(result.first[0]);
      if (!_cipher.containsPlaintextSensitiveField(raw)) {
        continue;
      }
      await upsertJson(key, raw);
      final verified = await getJson(key);
      if (_canonicalJson(verified) != _canonicalJson(raw)) {
        throw StateError('Encrypted settings backfill verification failed.');
      }
      migrated++;
    }
    return migrated;
  }

  Future<Map<String, dynamic>> getLocalAdminBootstrap() {
    return getJson('local_admin_bootstrap');
  }

  Future<bool> isBootstrapLoginEnabled() async {
    final raw = await getLocalAdminBootstrap();
    if (raw.isEmpty) {
      return false;
    }
    if (raw.containsKey('bootstrap_login_enabled')) {
      return raw['bootstrap_login_enabled'] == true;
    }
    final legacyCreatedEmail = (raw['created_email'] ?? '').toString().trim();
    final legacyBoundEmail = (raw['bound_email'] ?? '').toString().trim();
    final hasLegacyLock = (raw['locked_at'] ?? '').toString().trim().isNotEmpty;
    return legacyCreatedEmail.isNotEmpty &&
        legacyBoundEmail.isEmpty &&
        !hasLegacyLock;
  }

  Future<void> closeBootstrapLogin({required String boundEmail}) async {
    final current = await getLocalAdminBootstrap();
    await upsertJson('local_admin_bootstrap', {
      ...current,
      'allow_create': false,
      'bootstrap_login_enabled': false,
      'bootstrap_closed_at': DateTime.now().toUtc().toIso8601String(),
      'bound_email': boundEmail,
    });
  }

  Future<List<Map<String, dynamic>>> listEmailTemplates() async {
    final result = await _db.execute('''
      select name, subject, html, text, updated_at
      from email_templates
      order by name asc
      ''');

    return result
        .map(
          (row) => {
            'name': row[0],
            'subject': row[1],
            'html': row[2],
            'text': row[3],
            'updated_at': row[4].toString(),
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getEmailTemplate(String name) async {
    final result = await _db.execute(
      '''
      select name, subject, html, text, updated_at
      from email_templates
      where name = @name
      ''',
      params: {'name': name},
    );
    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return {
      'name': row[0],
      'subject': row[1],
      'html': row[2],
      'text': row[3],
      'updated_at': row[4].toString(),
    };
  }

  Future<void> upsertEmailTemplate({
    required String name,
    required String subject,
    required String html,
    required String text,
  }) async {
    await _db.execute(
      '''
      insert into email_templates(name, subject, html, text, updated_at)
      values (@name, @subject, @html, @text, now())
      on conflict (name)
      do update set subject = @subject, html = @html, text = @text, updated_at = now()
      ''',
      params: {'name': name, 'subject': subject, 'html': html, 'text': text},
    );
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw == null) {
      return {};
    }
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return {};
  }

  String _canonicalJson(dynamic value) {
    dynamic normalize(dynamic item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return {for (final key in keys) key: normalize(item[key])};
      }
      if (item is List) {
        return item.map(normalize).toList();
      }
      return item;
    }

    return jsonEncode(normalize(value));
  }
}
