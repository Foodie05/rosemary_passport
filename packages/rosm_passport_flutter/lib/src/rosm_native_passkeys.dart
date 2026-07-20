import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import 'models.dart';
import 'rosm_passport_logger.dart';

class RosmNativePasskeys {
  RosmNativePasskeys({bool debugMode = false, RosmPassportLogger? logger})
    : _authenticator = PasskeyAuthenticator(debugMode: debugMode),
      _logger = logger ?? RosmPassportLogging.logger;

  final PasskeyAuthenticator _authenticator;
  final RosmPassportLogger _logger;

  static Map<String, dynamic> normalizeOptionsForPlatform(
    RosmWebAuthnOptions options,
  ) {
    return _optionsMap(options);
  }

  Future<RosmWebAuthnCredential> authenticate(
    RosmWebAuthnOptions options, {
    MediationType mediation = MediationType.Required,
    bool preferImmediatelyAvailableCredentials = true,
  }) async {
    _logger.info(
      'Passkey authentication started.',
      source: 'rosm_passport.passkeys',
      event: 'passkey.authenticate.start',
    );
    try {
      final request = AuthenticateRequestType.fromJson(
        _optionsMap(options),
        mediation: mediation,
        preferImmediatelyAvailableCredentials:
            preferImmediatelyAvailableCredentials,
      );
      _logger.debug(
        'Passkey authentication options parsed.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.authenticate.options',
        context: {
          'rp_id': request.relyingPartyId,
          'challenge_length': request.challenge.length,
          'allow_credentials_count': request.allowCredentials?.length ?? 0,
          'user_verification': request.userVerification ?? 'preferred',
          'mediation': request.mediation.name,
          'prefer_immediately_available_credentials':
              request.preferImmediatelyAvailableCredentials,
        },
      );
      _logger.debug(
        'Calling native passkey authenticator.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.authenticate.native.start',
      );
      final response = await _authenticator.authenticate(request);
      _logger.debug(
        'Native passkey authenticator returned credential.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.authenticate.native.success',
        context: {
          'credential_id_length': response.id.length,
          'raw_id_length': response.rawId.length,
          'has_user_handle': response.userHandle.isNotEmpty,
          'client_data_json_length': response.clientDataJSON.length,
          'authenticator_data_length': response.authenticatorData.length,
          'signature_length': response.signature.length,
        },
      );
      _logger.info(
        'Passkey authentication completed.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.authenticate.success',
      );
      return RosmWebAuthnCredential(response.toJson());
    } on Object catch (error, stackTrace) {
      final exception = _passkeyException(error, registration: false);
      _logger.warning(
        'Passkey authentication failed.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.authenticate.failure',
        context: _failureContext(exception, error),
        error: exception,
        stackTrace: stackTrace,
      );
      throw exception;
    }
  }

  Future<RosmWebAuthnCredential> register(RosmWebAuthnOptions options) async {
    _logger.info(
      'Passkey registration started.',
      source: 'rosm_passport.passkeys',
      event: 'passkey.register.start',
    );
    try {
      final request = RegisterRequestType.fromJson(_optionsMap(options));
      _logger.debug(
        'Passkey registration options parsed.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.register.options',
        context: {
          'rp_id': request.relyingParty.id,
          'rp_name': request.relyingParty.name,
          'challenge_length': request.challenge.length,
          'user_id_length': request.user.id.length,
          'exclude_credentials_count': request.excludeCredentials.length,
          'pub_key_cred_params_count': request.pubKeyCredParams?.length ?? 0,
          'authenticator_attachment':
              request.authSelectionType?.authenticatorAttachment,
          'resident_key': request.authSelectionType?.residentKey,
          'user_verification': request.authSelectionType?.userVerification,
          'attestation': request.attestation ?? 'none',
        },
      );
      _logger.debug(
        'Calling native passkey registrar.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.register.native.start',
      );
      final response = await _authenticator.register(request);
      _logger.debug(
        'Native passkey registrar returned credential.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.register.native.success',
        context: {
          'credential_id_length': response.id.length,
          'raw_id_length': response.rawId.length,
          'client_data_json_length': response.clientDataJSON.length,
          'attestation_object_length': response.attestationObject.length,
          'transports_count': response.transports.whereType<String>().length,
          'transports': response.transports.whereType<String>().toList(),
        },
      );
      _logger.info(
        'Passkey registration completed.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.register.success',
      );
      return RosmWebAuthnCredential(response.toJson());
    } on Object catch (error, stackTrace) {
      final exception = _passkeyException(error, registration: true);
      _logger.warning(
        'Passkey registration failed.',
        source: 'rosm_passport.passkeys',
        event: 'passkey.register.failure',
        context: _failureContext(exception, error),
        error: exception,
        stackTrace: stackTrace,
      );
      throw exception;
    }
  }

  String _errorCode(Object error) {
    return error is RosmApiException
        ? error.code
        : error.runtimeType.toString();
  }

  Map<String, Object?> _failureContext(Object exception, Object original) {
    return {
      'error_code': _errorCode(exception),
      'original_error_type': original.runtimeType.toString(),
      'original_error': original.toString(),
    };
  }

  static Map<String, dynamic> _optionsMap(RosmWebAuthnOptions options) {
    final source = options.options['publicKey'] is Map
        ? options.options['publicKey']
        : options.options;
    final normalized = _deepStringKeyedMap(source);
    _normalizeCredentialDescriptors(normalized, 'allowCredentials');
    _normalizeCredentialDescriptors(normalized, 'excludeCredentials');
    return normalized;
  }

  static void _normalizeCredentialDescriptors(
    Map<String, dynamic> options,
    String key,
  ) {
    final descriptors = options[key];
    if (descriptors is! List) return;
    options[key] = descriptors
        .whereType<Map>()
        .map((descriptor) {
          final normalized = _deepStringKeyedMap(descriptor);
          normalized['type'] = normalized['type']?.toString().isNotEmpty == true
              ? normalized['type']
              : 'public-key';
          final transports = normalized['transports'];
          normalized['transports'] = transports is List
              ? transports.map((transport) => transport.toString()).toList()
              : <String>[];
          return normalized;
        })
        .toList(growable: false);
  }

  static Map<String, dynamic> _deepStringKeyedMap(Object? value) {
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

  static Object? _deepJsonValue(Object? value) {
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
    if (error is MalformedBase64Url ||
        error is FormatException ||
        error is TypeError) {
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

RosmNativePasskeys get rosmNativePasskeys =>
    RosmNativePasskeys(logger: RosmPassportLogging.logger);

Future<RosmWebAuthnCredential> authenticateRosmPasskey(
  RosmWebAuthnOptions options,
) {
  return RosmNativePasskeys(
    logger: RosmPassportLogging.logger,
  ).authenticate(options);
}

Future<RosmWebAuthnCredential> registerRosmPasskey(
  RosmWebAuthnOptions options,
) {
  return RosmNativePasskeys(
    logger: RosmPassportLogging.logger,
  ).register(options);
}
