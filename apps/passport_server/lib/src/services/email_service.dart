import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/app_config.dart';
import '../repositories/settings_repository.dart';

class EmailDeliveryException implements Exception {
  EmailDeliveryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class EmailService {
  EmailService(this._config, this._settingsRepository);

  final AppConfig _config;
  final SettingsRepository _settingsRepository;

  Future<void> sendVerificationCode({
    required String email,
    required String code,
    String templateName = 'register_verification',
  }) async {
    final smtp = await _resolveSmtpSettings();
    final template = await _settingsRepository.getEmailTemplate(
          templateName,
        ) ??
        _defaultTemplate();

    final subject =
        _renderTemplate(template['subject']?.toString() ?? '', code);
    final html = _renderTemplate(template['html']?.toString() ?? '', code);
    final text = _renderTemplate(template['text']?.toString() ?? '', code);

    final host = (smtp['host'] ?? '').toString();
    final port = smtp['port'] is int
        ? smtp['port'] as int
        : int.tryParse('${smtp['port']}') ?? 587;
    final username = (smtp['username'] ?? '').toString();
    final password = (smtp['password'] ?? '').toString();
    final secure = smtp['secure'] == true;
    final fromRaw = (smtp['from'] ?? '').toString();

    if (host.isEmpty || fromRaw.isEmpty) {
      throw EmailDeliveryException('SMTP is not configured.');
    }

    final from = _parseFromAddress(fromRaw);
    final smtpServer = SmtpServer(
      host,
      port: port,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
      ssl: secure,
      allowInsecure: !secure,
    );

    final message = Message()
      ..from = from
      ..recipients.add(email)
      ..subject = subject
      ..text = text
      ..html = html;

    try {
      await send(message, smtpServer);
    } catch (_) {
      throw EmailDeliveryException('SMTP delivery failed.');
    }
  }

  Future<Map<String, dynamic>> _resolveSmtpSettings() async {
    final fromDb = await _settingsRepository.getJson('smtp');
    return {
      'host': fromDb['host'] ?? _config.smtpHost,
      'port': fromDb['port'] ?? _config.smtpPort,
      'username': fromDb['username'] ?? _config.smtpUser,
      'password': fromDb['password'] ?? _config.smtpPassword,
      'from': fromDb['from'] ?? _config.smtpFrom,
      'secure': fromDb['secure'] ?? _config.smtpSecure,
    };
  }

  Map<String, String> _defaultTemplate() {
    return {
      'subject': 'ROSM通行证验证码',
      'html':
          '<div style="font-family:Arial,sans-serif;padding:16px"><h2 style="margin:0 0 10px;color:#0b6b61">ROSM通行证</h2><p>您的验证码是：<strong>{{code}}</strong></p><p style="color:#667085">有效期5分钟</p></div>',
      'text': 'ROSM通行证验证码: {{code}}，有效期5分钟。',
    };
  }

  String _renderTemplate(String value, String code) {
    return value.replaceAll('{{code}}', code);
  }

  Address _parseFromAddress(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'^(.*)\s<([^>]+)>$').firstMatch(trimmed);
    if (match == null) {
      return Address(trimmed);
    }
    final name = match.group(1)?.trim() ?? '';
    final email = match.group(2)?.trim() ?? '';
    return Address(email, name.isEmpty ? null : name);
  }
}
