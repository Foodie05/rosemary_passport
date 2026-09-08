import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import 'captcha_service.dart';
import 'auth_throttle_service.dart';

class BootstrapAccessService {
  BootstrapAccessService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required CaptchaService captchaService,
    required SettingsRepository settingsRepository,
    AuthThrottleService? throttleService,
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _captcha = captchaService,
       _settings = settingsRepository,
       _throttles = throttleService ?? AuthThrottleService();

  final UserRepository _users;
  final PasswordHasher _passwords;
  final CaptchaService _captcha;
  final SettingsRepository _settings;
  final AuthThrottleService _throttles;

  Future<bool> verifyCaptcha(String token, {String? ip}) {
    return _captcha.verifyCaptchaToken(token, remoteIp: ip);
  }

  Future<bool> shouldBypassCaptcha({
    required String email,
    required String password,
  }) async {
    final user = await _users.findByEmail(email);
    if (user == null || !await isBootstrapAdmin(user)) {
      return false;
    }
    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceLoginGuards(
      email: user.email,
      emailLimit: policy.loginEmailLimit,
      ipLimit: policy.loginIpLimit,
      window: Duration(seconds: policy.loginWindowSeconds),
      blockDuration: Duration(seconds: policy.loginBlockSeconds),
    );
    return limited == null &&
        await _passwords.verify(user.passwordHash, password);
  }

  Future<bool> shouldBypassCaptchaForUser(String userId) async {
    final user = await _users.findById(userId);
    return user != null && await isBootstrapAdmin(user);
  }

  bool mustBindAdminEmail(UserRecord user) {
    return user.roles.contains('admin') &&
        user.email.toLowerCase().trim().endsWith('@rosm.local');
  }

  Future<bool> isBootstrapAdmin(UserRecord user) async {
    return mustBindAdminEmail(user) &&
        await _settings.isBootstrapLoginEnabled();
  }
}
