import 'config/app_config.dart';
import 'db/database.dart';
import 'db/migration_runner.dart';
import 'repositories/email_code_repository.dart';
import 'repositories/oidc_repository.dart';
import 'repositories/security_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/webauthn_repository.dart';
import 'security/password_hasher.dart';
import 'security/password_policy.dart';
import 'security/settings_cipher.dart';
import 'security/token_service.dart';
import 'services/audit_service.dart';
import 'services/admin_settings_service.dart';
import 'services/authenticator_service.dart';
import 'services/auth_service.dart';
import 'services/captcha_service.dart';
import 'services/email_code_service.dart';
import 'services/email_service.dart';
import 'services/helper_client.dart';
import 'services/oidc_admin_service.dart';
import 'services/oidc_service.dart';
import 'services/phone_verification_service.dart';
import 'services/security_policy_service.dart';
import 'services/security_service.dart';
import 'services/token_validation_service.dart';
import 'services/webauthn_service.dart';

class AppServices {
  AppServices._(this.config) : _database = Database(config) {
    final settingsCipher = SettingsCipher(config);
    userRepository = UserRepository(_database, config, settingsCipher);
    emailCodeRepository = EmailCodeRepository(_database);
    oidcRepository = OidcRepository(_database);
    securityRepository = SecurityRepository(_database);
    settingsRepository = SettingsRepository(_database, settingsCipher);
    webAuthnRepository = WebAuthnRepository(_database);
    migrationRunner = MigrationRunner(_database);

    passwordHasher = PasswordHasher(config);
    passwordPolicy = PasswordPolicy();
    helperClient = HelperClient(config);
    tokenService = TokenService(config);
    tokenValidationService = TokenValidationService(
      tokenService,
      oidcRepository,
    );
    authenticatorService = AuthenticatorService();
    captchaService = CaptchaService(config, settingsRepository, helperClient);
    emailService = EmailService(config, settingsRepository);
    securityPolicyService = SecurityPolicyService(settingsRepository);
    emailCodeService = EmailCodeService(
      config,
      emailCodeRepository,
      emailService,
      securityPolicyService,
    );
    auditService = AuditService(_database);
    securityService = SecurityService(securityRepository);
    webAuthnService = WebAuthnService(
      config: config,
      repository: webAuthnRepository,
      helperClient: helperClient,
    );
    phoneVerificationService = PhoneVerificationService(
      config: config,
      settingsRepository: settingsRepository,
      securityService: securityService,
      securityPolicyService: securityPolicyService,
      helperClient: helperClient,
    );
    adminSettingsService = AdminSettingsService(
      settingsRepository,
      config,
      captchaService,
      securityPolicyService,
    );
    oidcAdminService = OidcAdminService(oidcRepository, passwordHasher);
    authService = AuthService(
      userRepository: userRepository,
      passwordHasher: passwordHasher,
      passwordPolicy: passwordPolicy,
      tokenService: tokenService,
      emailCodeService: emailCodeService,
      captchaService: captchaService,
      oidcRepository: oidcRepository,
      settingsRepository: settingsRepository,
      auditService: auditService,
      securityService: securityService,
      securityPolicyService: securityPolicyService,
      authenticatorService: authenticatorService,
      webAuthnService: webAuthnService,
      phoneVerificationService: phoneVerificationService,
    );
    oidcService = OidcService(
      config: config,
      oidcRepository: oidcRepository,
      userRepository: userRepository,
      tokenService: tokenService,
      tokenValidationService: tokenValidationService,
      passwordHasher: passwordHasher,
      authService: authService,
      securityService: securityService,
      securityPolicyService: securityPolicyService,
    );
  }

  static AppServices instance = AppServices._(AppConfig.fromEnv());

  final AppConfig config;
  final Database _database;
  late final MigrationRunner migrationRunner;

  Future<Map<String, dynamic>> readiness() async {
    final checks = <String, bool>{};
    try {
      await _database.execute('select 1');
      checks['database'] = true;
    } catch (_) {
      checks['database'] = false;
    }
    checks['migrations'] = await migrationRunner.isCurrent();
    checks['helper'] = await webAuthnService.healthCheck();
    return {
      'ready': checks.values.every((value) => value),
      'checks': checks,
      'migration_version': migrationRunner.latestVersion,
    };
  }

  late final UserRepository userRepository;
  late final EmailCodeRepository emailCodeRepository;
  late final OidcRepository oidcRepository;
  late final SecurityRepository securityRepository;
  late final SettingsRepository settingsRepository;
  late final WebAuthnRepository webAuthnRepository;

  late final PasswordHasher passwordHasher;
  late final PasswordPolicy passwordPolicy;
  late final HelperClient helperClient;
  late final TokenService tokenService;
  late final TokenValidationService tokenValidationService;
  late final AuthenticatorService authenticatorService;
  late final CaptchaService captchaService;
  late final EmailService emailService;
  late final EmailCodeService emailCodeService;
  late final AuditService auditService;
  late final SecurityService securityService;
  late final SecurityPolicyService securityPolicyService;
  late final OidcAdminService oidcAdminService;
  late final AuthService authService;
  late final OidcService oidcService;
  late final AdminSettingsService adminSettingsService;
  late final WebAuthnService webAuthnService;
  late final PhoneVerificationService phoneVerificationService;
}
