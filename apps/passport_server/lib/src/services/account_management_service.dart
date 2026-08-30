import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../security/password_hasher.dart';
import '../security/password_policy.dart';
import 'auth_attempts.dart';
import 'auth_throttle_service.dart';
import 'email_code_service.dart';
import 'phone_verification_service.dart';
import 'session_service.dart';

/// Manages authenticated account profile, binding, and password changes.
class AccountManagementService {
  AccountManagementService({
    required UserRepository userRepository,
    required SettingsRepository settingsRepository,
    required PasswordHasher passwordHasher,
    required PasswordPolicy passwordPolicy,
    required EmailCodeService emailCodeService,
    required AuthThrottleService throttleService,
    required SessionService sessionService,
    PhoneVerificationService? phoneVerificationService,
  }) : _users = userRepository,
       _settings = settingsRepository,
       _passwords = passwordHasher,
       _passwordPolicy = passwordPolicy,
       _emailCodes = emailCodeService,
       _throttles = throttleService,
       _sessions = sessionService,
       _phones = phoneVerificationService;

  static const _bindEmailScope = 'verification-code:bind-email:email';
  static const _bindIpScope = 'verification-code:bind-email:ip';
  static const _bindCooldownScope =
      'verification-code:bind-email:cooldown:email';
  static const _resetEmailScope = 'verification-code:password-reset:email';
  static const _resetIpScope = 'verification-code:password-reset:ip';
  static const _resetCooldownScope =
      'verification-code:password-reset:cooldown:email';

  final UserRepository _users;
  final SettingsRepository _settings;
  final PasswordHasher _passwords;
  final PasswordPolicy _passwordPolicy;
  final EmailCodeService _emailCodes;
  final AuthThrottleService _throttles;
  final SessionService _sessions;
  final PhoneVerificationService? _phones;

  Future<AccountUpdateAttempt> updateAccount({
    required String userId,
    required String currentPassword,
    String? nickname,
    String? newEmail,
    String? newPassword,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const AccountUpdateAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }

    var updatedEmail = false;
    var updatedPassword = false;
    var updatedNickname = false;
    if (nickname != null && nickname.trim().isNotEmpty) {
      await _users.updateNickname(userId: user.id, nickname: nickname.trim());
      updatedNickname = true;
    }

    final hasSensitiveChange =
        (newEmail != null && newEmail.trim().isNotEmpty) ||
        (newPassword != null && newPassword.trim().isNotEmpty);
    if (!hasSensitiveChange) {
      return AccountUpdateAttempt.success(
        updatedEmail: false,
        updatedPassword: false,
        updatedNickname: updatedNickname,
      );
    }
    if (currentPassword.isEmpty) {
      return const AccountUpdateAttempt.failure(
        code: 'invalid_request',
        message: 'current_password is required.',
      );
    }
    if (!await _passwords.verify(user.passwordHash, currentPassword)) {
      return const AccountUpdateAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }

    if (newEmail != null && newEmail.trim().isNotEmpty) {
      final targetEmail = newEmail.trim().toLowerCase();
      if (user.roles.contains('admin') &&
          isReservedBootstrapEmail(targetEmail)) {
        return const AccountUpdateAttempt.failure(
          code: 'invalid_email',
          message: '管理员邮箱不能使用保留的本地域名。',
        );
      }
      final existing = await _users.findByEmail(targetEmail);
      if (existing != null && existing.id != user.id) {
        return const AccountUpdateAttempt.failure(
          code: 'email_exists',
          message: '邮箱已被占用。',
          statusCode: 409,
        );
      }
      await _users.updateEmail(userId: user.id, email: targetEmail);
      updatedEmail = true;
    }

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      final policy = _passwordPolicy.validate(newPassword);
      if (!policy.ok) {
        return AccountUpdateAttempt.failure(
          code: 'password_policy_violation',
          message: policy.message!,
        );
      }
      final hash = await _passwords.hash(newPassword.trim());
      await _users.updatePasswordHash(userId: user.id, passwordHash: hash);
      updatedPassword = true;
    }

    if (updatedEmail || updatedPassword) {
      await _sessions.revokeAllUserSessions(user.id);
    }
    if (updatedEmail && await isBootstrapAdmin(user)) {
      await _settings.closeBootstrapLogin(
        boundEmail: newEmail!.trim().toLowerCase(),
      );
    }
    return AccountUpdateAttempt.success(
      updatedEmail: updatedEmail,
      updatedPassword: updatedPassword,
      updatedNickname: updatedNickname,
    );
  }

  Future<EmailActionAttempt> sendBindEmailCode({
    required String userId,
    required String newEmail,
    required String currentPassword,
    String? requestIp,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    final passwordFailure = await _validateCurrentPassword(
      user,
      currentPassword,
    );
    if (passwordFailure != null) {
      return passwordFailure;
    }
    final targetEmail = newEmail.trim().toLowerCase();
    final emailFailure = await _validateTargetEmail(user, targetEmail);
    if (emailFailure != null) {
      return emailFailure;
    }

    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceVerificationCodeSendGuards(
      email: targetEmail,
      requestIp: requestIp,
      policy: policy,
      emailScope: _bindEmailScope,
      ipScope: _bindIpScope,
      cooldownScope: _bindCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
    if (limited != null) {
      return EmailActionAttempt.failure(
        code: limited.code,
        message: limited.message,
        statusCode: limited.statusCode,
      );
    }
    await _emailCodes.issueBindEmailCode(targetEmail);
    await _throttles.startVerificationCodeCooldown(
      email: targetEmail,
      seconds: policy.bindEmailCodeCooldownSeconds,
      cooldownScope: _bindCooldownScope,
    );
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> bindEmail({
    required String userId,
    required String newEmail,
    required String currentPassword,
    required String emailCode,
    String? preservedAccessTokenId,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    if (emailCode.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'current_password and email_code are required.',
      );
    }
    final passwordFailure = await _validateCurrentPassword(
      user,
      currentPassword,
    );
    if (passwordFailure != null) {
      return passwordFailure;
    }
    final targetEmail = newEmail.trim().toLowerCase();
    final emailFailure = await _validateTargetEmail(user, targetEmail);
    if (emailFailure != null) {
      return emailFailure;
    }
    if (!await _emailCodes.verifyBindEmailCode(targetEmail, emailCode.trim())) {
      return const EmailActionAttempt.failure(
        code: 'invalid_code',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }
    await _users.updateEmail(userId: user.id, email: targetEmail);
    await _sessions.revokeAllUserSessions(
      user.id,
      preservedAccessTokenId: preservedAccessTokenId,
    );
    if (await isBootstrapAdmin(user)) {
      await _settings.closeBootstrapLogin(boundEmail: targetEmail);
    }
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> sendBindPhoneCode({
    required String userId,
    required String phoneNumber,
    required String currentPassword,
    String? requestIp,
  }) async {
    final resolved = await _resolvePhoneBinding(
      userId: userId,
      phoneNumber: phoneNumber,
      currentPassword: currentPassword,
      verifyCode: null,
    );
    if (resolved.failure != null) {
      return resolved.failure!;
    }
    final sent = await resolved.service!.sendCode(
      phoneNumber: resolved.phoneNumber!,
      requestIp: requestIp?.trim() ?? '',
    );
    return sent.ok
        ? const EmailActionAttempt.success()
        : EmailActionAttempt.failure(
            code: sent.code ?? 'temporary_issue',
            message: sent.message ?? '验证码发送失败，请稍后重试。',
            statusCode: sent.statusCode,
          );
  }

  Future<EmailActionAttempt> bindPhone({
    required String userId,
    required String phoneNumber,
    required String currentPassword,
    required String verifyCode,
    String? requestIp,
    String? preservedAccessTokenId,
  }) async {
    final resolved = await _resolvePhoneBinding(
      userId: userId,
      phoneNumber: phoneNumber,
      currentPassword: currentPassword,
      verifyCode: verifyCode,
    );
    if (resolved.failure != null) {
      return resolved.failure!;
    }
    final checked = await resolved.service!.verifyCode(
      phoneNumber: resolved.phoneNumber!,
      verifyCode: verifyCode,
      requestIp: requestIp?.trim() ?? '',
    );
    if (!checked.ok) {
      return EmailActionAttempt.failure(
        code: checked.code ?? 'invalid_code',
        message: checked.message ?? '验证码无效或已过期。',
        statusCode: checked.statusCode,
      );
    }
    await _users.updatePhoneNumber(
      userId: resolved.user!.id,
      phoneNumber: resolved.phoneNumber!,
    );
    await _sessions.revokeAllUserSessions(
      resolved.user!.id,
      preservedAccessTokenId: preservedAccessTokenId,
    );
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> sendPasswordResetCode({
    required String userId,
    String? requestIp,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    final policy = await _throttles.loadPolicy();
    final limited = await _throttles.enforceVerificationCodeSendGuards(
      email: user.email,
      requestIp: requestIp,
      policy: policy,
      emailScope: _resetEmailScope,
      ipScope: _resetIpScope,
      cooldownScope: _resetCooldownScope,
      emailLimit: policy.adminLoginCodeEmailLimit,
      ipLimit: policy.adminLoginCodeIpLimit,
    );
    if (limited != null) {
      return EmailActionAttempt.failure(
        code: limited.code,
        message: limited.message,
        statusCode: limited.statusCode,
      );
    }
    await _emailCodes.issuePasswordResetCode(user.email);
    await _throttles.startVerificationCodeCooldown(
      email: user.email,
      seconds: policy.passwordResetCodeCooldownSeconds,
      cooldownScope: _resetCooldownScope,
    );
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt> resetPassword({
    required String userId,
    required String newPassword,
    required String emailCode,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const EmailActionAttempt.failure(
        code: 'not_found',
        message: 'User not found.',
        statusCode: 404,
      );
    }
    if (newPassword.trim().isEmpty || emailCode.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'new_password and email_code are required.',
      );
    }
    final policy = _passwordPolicy.validate(newPassword);
    if (!policy.ok) {
      return EmailActionAttempt.failure(
        code: 'password_policy_violation',
        message: policy.message!,
      );
    }
    if (!await _emailCodes.verifyPasswordResetCode(
      user.email,
      emailCode.trim(),
    )) {
      return const EmailActionAttempt.failure(
        code: 'invalid_code',
        message: '邮箱验证码无效或已过期。',
        statusCode: 401,
      );
    }
    final hash = await _passwords.hash(newPassword.trim());
    await _users.updatePasswordHash(userId: user.id, passwordHash: hash);
    await _sessions.revokeAllUserSessions(user.id);
    return const EmailActionAttempt.success();
  }

  Future<EmailActionAttempt?> _validateCurrentPassword(
    UserRecord user,
    String currentPassword,
  ) async {
    if (currentPassword.trim().isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'current_password is required.',
      );
    }
    if (!await _passwords.verify(user.passwordHash, currentPassword)) {
      return const EmailActionAttempt.failure(
        code: 'invalid_password',
        message: '当前密码错误。',
        statusCode: 401,
      );
    }
    return null;
  }

  Future<EmailActionAttempt?> _validateTargetEmail(
    UserRecord user,
    String targetEmail,
  ) async {
    if (targetEmail.isEmpty) {
      return const EmailActionAttempt.failure(
        code: 'invalid_request',
        message: 'email is required.',
      );
    }
    if (user.roles.contains('admin') && isReservedBootstrapEmail(targetEmail)) {
      return const EmailActionAttempt.failure(
        code: 'invalid_email',
        message: '管理员邮箱不能使用保留的本地域名。',
      );
    }
    final existing = await _users.findByEmail(targetEmail);
    if (existing != null && existing.id != user.id) {
      return const EmailActionAttempt.failure(
        code: 'email_exists',
        message: '邮箱已被占用。',
        statusCode: 409,
      );
    }
    return null;
  }

  Future<_PhoneBindingResolution> _resolvePhoneBinding({
    required String userId,
    required String phoneNumber,
    required String currentPassword,
    required String? verifyCode,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) {
      return const _PhoneBindingResolution.failure(
        EmailActionAttempt.failure(
          code: 'not_found',
          message: 'User not found.',
          statusCode: 404,
        ),
      );
    }
    if (verifyCode != null && verifyCode.trim().isEmpty) {
      return const _PhoneBindingResolution.failure(
        EmailActionAttempt.failure(
          code: 'invalid_request',
          message: 'current_password and verify_code are required.',
        ),
      );
    }
    final passwordFailure = await _validateCurrentPassword(
      user,
      currentPassword,
    );
    if (passwordFailure != null) {
      return _PhoneBindingResolution.failure(passwordFailure);
    }
    final phones = _phones;
    if (phones == null) {
      return const _PhoneBindingResolution.failure(
        EmailActionAttempt.failure(
          code: 'phone_verification_not_configured',
          message: '手机号验证码服务尚未配置。',
          statusCode: 503,
        ),
      );
    }
    final normalized = phones.normalizePhone(phoneNumber);
    if (normalized == null) {
      return const _PhoneBindingResolution.failure(
        EmailActionAttempt.failure(
          code: 'invalid_phone_number',
          message: '手机号格式不正确。',
        ),
      );
    }
    final existing = await _users.findByPhoneNumber(normalized);
    if (existing != null && existing.id != user.id) {
      return const _PhoneBindingResolution.failure(
        EmailActionAttempt.failure(
          code: 'phone_exists',
          message: '手机号已被占用。',
          statusCode: 409,
        ),
      );
    }
    return _PhoneBindingResolution.success(user, phones, normalized);
  }

  Future<bool> isBootstrapAdmin(UserRecord user) async {
    return user.roles.contains('admin') &&
        isReservedBootstrapEmail(user.email) &&
        await _settings.isBootstrapLoginEnabled();
  }

  bool isReservedBootstrapEmail(String email) {
    return email.toLowerCase().trim().endsWith('@rosm.local');
  }
}

class _PhoneBindingResolution {
  const _PhoneBindingResolution.success(
    this.user,
    this.service,
    this.phoneNumber,
  ) : failure = null;

  const _PhoneBindingResolution.failure(this.failure)
    : user = null,
      service = null,
      phoneNumber = null;

  final UserRecord? user;
  final PhoneVerificationService? service;
  final String? phoneNumber;
  final EmailActionAttempt? failure;
}
