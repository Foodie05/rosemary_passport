import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import 'models.dart';

class RosmNativePasskeys {
  RosmNativePasskeys({bool debugMode = false})
    : _authenticator = PasskeyAuthenticator(debugMode: debugMode);

  final PasskeyAuthenticator _authenticator;

  Future<RosmWebAuthnCredential> authenticate(
    RosmWebAuthnOptions options, {
    MediationType mediation = MediationType.Required,
    bool preferImmediatelyAvailableCredentials = true,
  }) async {
    try {
      final request = AuthenticateRequestType.fromJson(
        _optionsMap(options),
        mediation: mediation,
        preferImmediatelyAvailableCredentials:
            preferImmediatelyAvailableCredentials,
      );
      final response = await _authenticator.authenticate(request);
      return RosmWebAuthnCredential(response.toJson());
    } on Object catch (error) {
      throw _passkeyException(error, registration: false);
    }
  }

  Future<RosmWebAuthnCredential> register(RosmWebAuthnOptions options) async {
    try {
      final request = RegisterRequestType.fromJson(_optionsMap(options));
      final response = await _authenticator.register(request);
      return RosmWebAuthnCredential(response.toJson());
    } on Object catch (error) {
      throw _passkeyException(error, registration: true);
    }
  }

  Map<String, dynamic> _optionsMap(RosmWebAuthnOptions options) {
    final source = options.options['publicKey'] is Map
        ? options.options['publicKey']
        : options.options;
    return _deepStringKeyedMap(source);
  }

  Map<String, dynamic> _deepStringKeyedMap(Object? value) {
    if (value is! Map) {
      throw const RosmApiException(
        'invalid_passkey_options',
        'ROSM Passport 返回的通行密钥参数格式不正确。',
      );
    }
    return value.map<String, dynamic>(
      (key, child) => MapEntry(key.toString(), _deepJsonValue(child)),
    );
  }

  Object? _deepJsonValue(Object? value) {
    if (value is Map) {
      return _deepStringKeyedMap(value);
    }
    if (value is List) {
      return value.map(_deepJsonValue).toList(growable: false);
    }
    return value;
  }

  Exception _passkeyException(Object error, {required bool registration}) {
    if (error is RosmApiException) return error;
    if (error is PasskeyAuthCancelledException) {
      return const RosmApiException('passkey_cancelled', '已取消通行密钥操作。');
    }
    if (error is NoCredentialsAvailableException) {
      return const RosmApiException('passkey_not_found', '当前设备没有可用于此账号的通行密钥。');
    }
    if (error is ExcludeCredentialsCanNotBeRegisteredException) {
      return const RosmApiException(
        'passkey_already_exists',
        '这个设备上已经存在可用的通行密钥。',
      );
    }
    if (error is DomainNotAssociatedException) {
      return RosmApiException(
        'passkey_domain_not_associated',
        error.message ?? '应用尚未完成通行密钥域名关联配置。',
      );
    }
    if (error is MissingGoogleSignInException ||
        error is SyncAccountNotAvailableException) {
      return const RosmApiException(
        'passkey_account_unavailable',
        '请先在系统中登录并启用可同步通行密钥的账号。',
      );
    }
    if (error is DeviceNotSupportedException ||
        error is PasskeyUnsupportedException ||
        error is NoCreateOptionException) {
      return RosmApiException(
        'passkey_not_supported',
        registration ? '当前设备暂不支持添加通行密钥。' : '当前设备暂不支持使用通行密钥登录。',
      );
    }
    if (error is TimeoutException) {
      return const RosmApiException('passkey_timeout', '通行密钥操作已超时，请重试。');
    }
    if (error is MalformedBase64Url || error is FormatException) {
      return const RosmApiException(
        'invalid_passkey_options',
        'ROSM Passport 返回的通行密钥参数格式不正确。',
      );
    }
    return RosmApiException(
      'passkey_failed',
      registration ? '添加通行密钥失败，请稍后重试。' : '通行密钥验证失败，请稍后重试。',
    );
  }
}

final RosmNativePasskeys rosmNativePasskeys = RosmNativePasskeys();

Future<RosmWebAuthnCredential> authenticateRosmPasskey(
  RosmWebAuthnOptions options,
) {
  return rosmNativePasskeys.authenticate(options);
}

Future<RosmWebAuthnCredential> registerRosmPasskey(
  RosmWebAuthnOptions options,
) {
  return rosmNativePasskeys.register(options);
}
