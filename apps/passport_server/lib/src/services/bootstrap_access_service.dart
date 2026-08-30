import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import 'captcha_service.dart';

class BootstrapAccessService {
  BootstrapAccessService({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required CaptchaService captchaService,
    required SettingsRepository settingsRepository,
  }) : _users = userRepository,
       _passwords = passwordHasher,
       _captcha = captchaService,
       _settings = settingsRepository;

  final UserRepository _users;
  final PasswordHasher _passwords;
  final CaptchaService _captcha;
  final SettingsRepository _settings;

  Future<bool> verifyCaptcha(String token, {String? ip}) {
    return _captcha.verifyCaptchaToken(token, remoteIp: ip);
  }

  Future<bool> shouldBypassCaptcha({
    required String email,
    required String password,
  }) async {
    final user = await _users.findByEmail(email);
    if (user == null || !await _passwords.verify(user.passwordHash, password)) {
      return false;
    }
    return isBootstrapAdmin(user);
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
