import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../repositories/settings_repository.dart';

class CaptchaService {
  CaptchaService(this._config, [this._settingsRepository]);

  final AppConfig _config;
  final SettingsRepository? _settingsRepository;

  static const _verifyTimeout = Duration(seconds: 8);

  Future<bool> verifyCaptchaToken(String token, {String? remoteIp}) async {
    final result = await verifyCaptchaConfiguration(token: token);
    return result['ok'] == true;
  }

  Future<Map<String, dynamic>> verifyCaptchaConfiguration({
    required String token,
  }) async {
    final provider = await _resolveProviderSettings();
    if (provider.values.any((value) => value.isEmpty)) {
      // ignore: avoid_print
      print(
        '[ALIYUN_CAPTCHA] Verification skipped: configuration is incomplete.',
      );
      return {'ok': false, 'message': '阿里云验证码配置不完整。'};
    }

    late final Process process;
    try {
      process = await Process.start('node', [
        'scripts/captcha-verify.mjs',
      ], workingDirectory: Directory.current.path);
      process.stdin.writeln(
        jsonEncode({
          'accessKeyId': provider['accessKeyId'],
          'accessKeySecret': provider['accessKeySecret'],
          'sceneId': provider['sceneId'],
          'captchaVerifyParam': token,
        }),
      );
      await process.stdin.close();

      final outputFuture = process.stdout.transform(utf8.decoder).join();
      final errorFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(_verifyTimeout);
      final output = await outputFuture;
      final errorOutput = await errorFuture;
      if (exitCode != 0) {
        final normalizedError = errorOutput.toLowerCase();
        if (normalizedError.contains('invalidaccesskeyid') ||
            normalizedError.contains('signaturedoesnotmatch') ||
            normalizedError.contains('invalidsecuritytoken')) {
          return {
            'ok': false,
            'message':
                '阿里云 AccessKey 无效，请检查 RAM 用户的 AccessKey ID 和 AccessKey Secret。',
          };
        }
        if (normalizedError.contains('forbidden') ||
            normalizedError.contains('no permission') ||
            normalizedError.contains('unauthorized')) {
          return {
            'ok': false,
            'message': '当前 RAM 用户无权校验验证码，请授予 AliyunYundunAFSFullAccess。',
          };
        }
        if (normalizedError.contains('enotfound') ||
            normalizedError.contains('econnrefused') ||
            normalizedError.contains('econnreset')) {
          return {'ok': false, 'message': '无法连接阿里云验证码接口，请检查服务器 DNS、网络和代理配置。'};
        }
        throw StateError(
          'Captcha helper exited with $exitCode (${errorOutput.length} stderr bytes).',
        );
      }

      final body = Map<String, dynamic>.from(jsonDecode(output) as Map);
      final providerAccepted = body['success'] == true;
      final verified = body['verifyResult'] == true;
      if (providerAccepted && verified) {
        // ignore: avoid_print
        print(
          '[ALIYUN_CAPTCHA] Verification succeeded '
          '(token_length=${token.length}, request_id=${body['requestId'] ?? ''}).',
        );
        return {'ok': true, 'message': '阿里云验证码校验成功。'};
      }

      final verifyCode = '${body['verifyCode'] ?? ''}';
      final providerCode = '${body['code'] ?? ''}';
      final providerMessage = _safeDiagnosticValue(body['message']);
      final requestId = _safeDiagnosticValue(body['requestId']);
      // ignore: avoid_print
      print(
        '[ALIYUN_CAPTCHA] Verification rejected by provider '
        '(code=$providerCode, verify_code=$verifyCode, '
        'message=$providerMessage, request_id=$requestId, '
        'token_length=${token.length}).',
      );
      final details = <String>[
        if (providerMessage.isNotEmpty) providerMessage,
        if (providerCode.isNotEmpty && providerCode != verifyCode)
          '接口代码：$providerCode',
        if (requestId.isNotEmpty) '请求 ID：$requestId',
      ];
      final detailSuffix = details.isEmpty ? '' : ' ${details.join('；')}';
      return {
        'ok': false,
        'message': verifyCode.isEmpty
            ? '阿里云验证码校验失败。$detailSuffix'
            : '阿里云验证码校验未通过（$verifyCode）。$detailSuffix',
      };
    } on TimeoutException {
      process.kill();
      // Never log the token or secret; lengths are enough for diagnostics.
      // ignore: avoid_print
      print(
        '[ALIYUN_CAPTCHA] Verification timed out after '
        '${_verifyTimeout.inSeconds}s (token_length=${token.length}).',
      );
      return {'ok': false, 'message': '阿里云验证码校验服务连接超时，请稍后重试。'};
    } catch (error) {
      // ignore: avoid_print
      print(
        '[ALIYUN_CAPTCHA] Verification request failed: '
        '${error.runtimeType} (token_length=${token.length}).',
      );
      return {'ok': false, 'message': '无法连接到阿里云验证码校验服务，请检查服务器网络与配置。'};
    }
  }

  static String _safeDiagnosticValue(dynamic value) {
    final normalized = '${value ?? ''}'
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    if (normalized.length <= 240) {
      return normalized;
    }
    return normalized.substring(0, 240);
  }

  Future<Map<String, String>> _resolveProviderSettings() async {
    final security =
        await _settingsRepository?.getJson('security') ??
        const <String, dynamic>{};
    String read(String key, String fallback) {
      final value = (security[key] ?? '').toString().trim();
      return value.isNotEmpty ? value : fallback;
    }

    final smsAccessKeyId = read(
      'phone_sms_access_key_id',
      _config.aliyunCaptchaAccessKeyId,
    );
    final smsAccessKeySecret = read(
      'phone_sms_access_key_secret',
      _config.aliyunCaptchaAccessKeySecret,
    );
    return {
      'prefix': read('aliyun_captcha_prefix', _config.aliyunCaptchaPrefix),
      'sceneId': read('aliyun_captcha_scene_id', _config.aliyunCaptchaSceneId),
      'accessKeyId': read('aliyun_captcha_access_key_id', smsAccessKeyId),
      'accessKeySecret': read(
        'aliyun_captcha_access_key_secret',
        smsAccessKeySecret,
      ),
    };
  }
}
