import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../repositories/email_code_repository.dart';
import 'email_service.dart';
import 'security_policy_service.dart';

class EmailCodeService {
  EmailCodeService(
    this._config,
    this._repository,
    this._emailService,
    SecurityPolicyService? securityPolicyService,
  ) : _securityPolicyService = securityPolicyService;

  final AppConfig _config;
  final EmailCodeRepository _repository;
  final EmailService _emailService;
  SecurityPolicyService? _securityPolicyService;
  final _random = Random.secure();

  Future<void> issueRegisterCode(String email) async {
    await issueCode(
      email,
      purpose: 'register',
      templateName: 'register_verification',
    );
  }

  Future<void> issueBindEmailCode(String email) async {
    await issueCode(
      email,
      purpose: 'bind_email',
      templateName: 'register_verification',
    );
  }

  Future<void> issuePasswordResetCode(String email) async {
    await issueCode(
      email,
      purpose: 'password_reset',
      templateName: 'login_verification',
    );
  }

  Future<void> issueCode(
    String email, {
    required String purpose,
    required String templateName,
  }) async {
    final code = _generateCode();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(seconds: _config.emailCodeTtlSeconds));

    await _repository.storeCode(
      email: email,
      codeHash: _digest(email: email, code: code),
      purpose: purpose,
      expiresAt: expiresAt,
    );

    await _emailService.sendVerificationCode(
      email: email,
      code: code,
      templateName: templateName,
    );
  }

  Future<void> issueAdminLoginCode(String email) async {
    await issueLoginCode(email, templateName: 'admin_login_verification');
  }

  Future<void> issueLoginCode(
    String email, {
    String templateName = 'login_verification',
  }) async {
    final code = _generateCode();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(seconds: _config.emailCodeTtlSeconds));

    await _repository.storeCode(
      email: email,
      codeHash: _digest(email: email, code: code),
      purpose: 'login',
      expiresAt: expiresAt,
    );

    await _emailService.sendVerificationCode(
      email: email,
      code: code,
      templateName: templateName,
    );
  }

  Future<bool> verifyRegisterCode(String email, String code) async {
    return _verifyCode(email: email, code: code, purpose: 'register');
  }

  Future<bool> verifyBindEmailCode(String email, String code) async {
    return _verifyCode(email: email, code: code, purpose: 'bind_email');
  }

  Future<bool> verifyAdminLoginCode(String email, String code) async {
    return verifyLoginCode(email, code);
  }

  Future<bool> verifyLoginCode(String email, String code) async {
    return _verifyCode(email: email, code: code, purpose: 'login');
  }

  Future<String?> validateLoginCode(String email, String code) {
    return _validateCodeId(email: email, code: code, purpose: 'login');
  }

  Future<bool> consumeCode(String codeId) {
    return _repository.markUsedIfAvailable(codeId);
  }

  Future<bool> verifyPasswordResetCode(String email, String code) async {
    return _verifyCode(email: email, code: code, purpose: 'password_reset');
  }

  Future<bool> _verifyCode({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final codeId = await _validateCodeId(
      email: email,
      code: code,
      purpose: purpose,
    );
    if (codeId == null) {
      return false;
    }
    return _repository.markUsedIfAvailable(codeId);
  }

  Future<String?> _validateCodeId({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final item = await _repository.findLatestCode(email: email, purpose: purpose);
    if (item == null) {
      return null;
    }

    final usedAt = item['used_at'] as DateTime?;
    final expiresAt = item['expires_at'] as DateTime;
    final failedAttempts = item['failed_attempts'] as int? ?? 0;
    final policy = _securityPolicyService == null
        ? SecurityPolicyService.defaultPolicy
        : await _securityPolicyService!.load();
    if (usedAt != null ||
        expiresAt.isBefore(DateTime.now().toUtc()) ||
        failedAttempts >= policy.emailCodeMaxAttempts) {
      return null;
    }

    final expectedHash = item['code_hash'] as String;
    final inputHash = _digest(email: email, code: code);
    if (expectedHash != inputHash) {
      await _repository.markFailed(item['id'] as String);
      return null;
    }

    return item['id'] as String;
  }

  String _generateCode() {
    final value = _random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  String _digest({required String email, required String code}) {
    final key = utf8.encode(_config.emailCodeHmacKey);
    final bytes = utf8.encode('${email.toLowerCase().trim()}::$code');
    return Hmac(sha256, key).convert(bytes).toString();
  }
}
