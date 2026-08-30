import '../lib/src/config/app_config.dart';
import '../lib/src/db/database.dart';
import '../lib/src/db/migration_runner.dart';
import '../lib/src/repositories/settings_repository.dart';
import '../lib/src/repositories/user_repository.dart';
import '../lib/src/security/settings_cipher.dart';
import '../lib/src/services/audit_service.dart';

Future<void> main() async {
  final config = AppConfig.fromEnv();
  final database = Database(config);
  try {
    await database.warmUp();
    await MigrationRunner(database).migrate();
    final migratedAuditEntries = await AuditService(
      database,
    ).backfillLegacyHashes();
    final cipher = SettingsCipher(config);
    final settings = SettingsRepository(database, cipher);
    final migratedSettings = await settings.migratePlaintextSecrets();
    final migratedAuthenticators = await UserRepository(
      database,
      config,
      cipher,
    ).migratePlaintextAuthenticatorSecrets();
    // ignore: avoid_print
    print(
      'Database migrations are current; encrypted settings: '
      '$migratedSettings; encrypted authenticators: '
      '$migratedAuthenticators; hashed legacy audit entries: '
      '$migratedAuditEntries.',
    );
  } finally {
    await database.close();
  }
}
