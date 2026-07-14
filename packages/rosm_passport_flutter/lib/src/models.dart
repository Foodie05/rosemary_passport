import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

class UriStringConverter implements JsonConverter<Uri, String> {
  const UriStringConverter();

  @override
  Uri fromJson(String json) => Uri.parse(json);

  @override
  String toJson(Uri object) => object.toString();
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmAuthorizationRequest {
  const RosmAuthorizationRequest({
    required this.clientId,
    required this.redirectUri,
    required this.responseType,
    required this.scope,
    required this.state,
    required this.nonce,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.codeChallengeMethod,
  });

  final String clientId;
  @UriStringConverter()
  final Uri redirectUri;
  final String responseType;
  final String scope;
  final String state;
  final String nonce;
  @JsonKey(includeToJson: false)
  final String codeVerifier;
  final String codeChallenge;
  final String codeChallengeMethod;

  Map<String, dynamic> toJson() => _$RosmAuthorizationRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: false,
)
class RosmNativeAuthorizationRequest {
  const RosmNativeAuthorizationRequest({
    required this.clientId,
    required this.redirectUri,
    required this.responseType,
    required this.scope,
    this.state,
    this.nonce,
    this.codeChallenge,
    this.codeChallengeMethod,
  });

  factory RosmNativeAuthorizationRequest.fromJson(Map<String, dynamic> json) =>
      _$RosmNativeAuthorizationRequestFromJson(json);

  final String clientId;
  @UriStringConverter()
  final Uri redirectUri;
  final String responseType;
  final String scope;
  final String? state;
  final String? nonce;
  final String? codeChallenge;
  final String? codeChallengeMethod;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmAuthorizationStart {
  const RosmAuthorizationStart({
    required this.issuer,
    required this.authorizationRequest,
    required this.client,
    required this.scopes,
    required this.pkceRequired,
  });

  factory RosmAuthorizationStart.fromJson(Map<String, dynamic> json) =>
      _$RosmAuthorizationStartFromJson(json);

  @UriStringConverter()
  final Uri issuer;
  final RosmNativeAuthorizationRequest authorizationRequest;
  final RosmClientInfo client;
  final List<RosmScopeInfo> scopes;
  final bool pkceRequired;
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: false,
)
class RosmAuthorizationApproval {
  const RosmAuthorizationApproval({
    required this.code,
    required this.redirectUri,
    required this.callbackUrl,
    this.state,
  });

  factory RosmAuthorizationApproval.fromJson(Map<String, dynamic> json) =>
      _$RosmAuthorizationApprovalFromJson(json);

  final String code;
  final String? state;
  @UriStringConverter()
  final Uri redirectUri;
  @UriStringConverter()
  final Uri callbackUrl;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmClientInfo {
  const RosmClientInfo({
    required this.clientId,
    required this.displayName,
    required this.isOfficial,
  });

  factory RosmClientInfo.fromJson(Map<String, dynamic> json) =>
      _$RosmClientInfoFromJson(json);

  final String clientId;
  final String displayName;
  final bool isOfficial;
}

@JsonSerializable(createToJson: false)
class RosmScopeInfo {
  const RosmScopeInfo({required this.name, required this.description});

  factory RosmScopeInfo.fromJson(Map<String, dynamic> json) =>
      _$RosmScopeInfoFromJson(json);

  final String name;
  final String description;
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class RosmTokenSet {
  const RosmTokenSet({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    this.idToken,
  });

  factory RosmTokenSet.fromJson(Map<String, dynamic> json) =>
      _$RosmTokenSetFromJson(json);

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String? idToken;

  Map<String, dynamic> toJson() => _$RosmTokenSetToJson(this);

  Map<String, String> toStorageJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_in': expiresIn.toString(),
    if (idToken != null) 'id_token': idToken!,
  };
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: false,
)
class RosmUser {
  const RosmUser({
    required this.id,
    required this.email,
    required this.nickname,
    required this.roles,
    this.phoneNumber,
    this.isPhoneVerified = false,
  });

  factory RosmUser.fromJson(Map<String, dynamic> json) =>
      _$RosmUserFromJson(json);

  final String id;
  final String email;
  final String nickname;
  final List<String> roles;
  final String? phoneNumber;
  final bool isPhoneVerified;

  bool get isAdmin => roles.contains('admin');
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: false,
)
class RosmSecurityState {
  const RosmSecurityState({
    this.mustBindEmail = false,
    this.adminMfaRequired = false,
    this.hasPasskey = false,
    this.hasAuthenticator = false,
    this.hasPhone = false,
  });

  factory RosmSecurityState.fromJson(Map<String, dynamic> json) =>
      _$RosmSecurityStateFromJson(json);

  final bool mustBindEmail;
  final bool adminMfaRequired;
  final bool hasPasskey;
  final bool hasAuthenticator;
  final bool hasPhone;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmAuthResult {
  const RosmAuthResult({
    required this.user,
    required this.security,
    required this.postRegisterPasskeyBootstrap,
  });

  factory RosmAuthResult.fromJson(Map<String, dynamic> json) =>
      _$RosmAuthResultFromJson(json);

  final RosmUser user;
  final RosmSecurityState security;
  final bool postRegisterPasskeyBootstrap;
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: false,
)
class RosmUserInfo {
  const RosmUserInfo({
    required this.sub,
    this.email,
    this.emailVerified,
    this.phoneNumber,
    this.phoneNumberVerified,
    this.name,
    this.nickname,
    this.roles = const [],
  });

  factory RosmUserInfo.fromJson(Map<String, dynamic> json) =>
      _$RosmUserInfoFromJson(json);

  final String sub;
  final String? email;
  final bool? emailVerified;
  final String? phoneNumber;
  final bool? phoneNumberVerified;
  final String? name;
  final String? nickname;
  final List<String> roles;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmPasswordFactors {
  const RosmPasswordFactors({
    required this.factors,
    required this.directLogin,
    this.defaultFactor,
  });

  factory RosmPasswordFactors.fromJson(Map<String, dynamic> json) =>
      _$RosmPasswordFactorsFromJson(json);

  final List<String> factors;
  final String? defaultFactor;
  final bool directLogin;
}

enum RosmPasswordRecoveryMethod {
  email,
  phone;

  String get wireName => switch (this) {
    RosmPasswordRecoveryMethod.email => 'email',
    RosmPasswordRecoveryMethod.phone => 'phone',
  };
}

class RosmPasswordRecoveryMethodConverter
    implements JsonConverter<RosmPasswordRecoveryMethod, String> {
  const RosmPasswordRecoveryMethodConverter();

  @override
  RosmPasswordRecoveryMethod fromJson(String json) {
    return switch (json) {
      'email' => RosmPasswordRecoveryMethod.email,
      'phone' => RosmPasswordRecoveryMethod.phone,
      _ => throw ArgumentError.value(
        json,
        'json',
        'Unsupported recovery method',
      ),
    };
  }

  @override
  String toJson(RosmPasswordRecoveryMethod object) => object.wireName;
}

class RosmWebAuthnOptions {
  const RosmWebAuthnOptions(this.options);

  factory RosmWebAuthnOptions.fromJson(Map<String, dynamic> json) =>
      RosmWebAuthnOptions(json);

  final Map<String, dynamic> options;
}

class RosmWebAuthnCredential {
  const RosmWebAuthnCredential(this.response);

  final Map<String, dynamic> response;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmOperationResult {
  const RosmOperationResult({
    this.sent = false,
    this.updated = false,
    this.deleted = false,
    this.message,
  });

  factory RosmOperationResult.fromJson(Map<String, dynamic> json) =>
      _$RosmOperationResultFromJson(json);

  final bool sent;
  final bool updated;
  final bool deleted;
  final String? message;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmWebAuthnCredentialInfo {
  const RosmWebAuthnCredentialInfo({
    required this.credentialId,
    required this.createdAt,
    this.deviceType,
    this.backedUp = false,
    this.transports = const [],
  });

  factory RosmWebAuthnCredentialInfo.fromJson(Map<String, dynamic> json) =>
      _$RosmWebAuthnCredentialInfoFromJson(json);

  final String credentialId;
  final String? deviceType;
  final bool backedUp;
  final List<String> transports;
  final DateTime createdAt;
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class RosmPasskeyList {
  const RosmPasskeyList({required this.credentials, required this.maxCount});

  factory RosmPasskeyList.fromJson(Map<String, dynamic> json) =>
      _$RosmPasskeyListFromJson(json);

  final List<RosmWebAuthnCredentialInfo> credentials;
  final int maxCount;
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmPasswordFactorsRequest {
  const RosmPasswordFactorsRequest({
    required this.email,
    required this.password,
    this.captchaToken,
  });

  final String email;
  final String password;
  final String? captchaToken;

  Map<String, dynamic> toJson() => _$RosmPasswordFactorsRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmPasswordLoginRequest {
  const RosmPasswordLoginRequest({
    required this.email,
    required this.password,
    this.factorType,
    this.emailCode,
    this.phoneCode,
    this.authenticatorCode,
    this.captchaToken,
  });

  final String email;
  final String password;
  final String? factorType;
  final String? emailCode;
  final String? phoneCode;
  final String? authenticatorCode;
  final String? captchaToken;

  Map<String, dynamic> toJson() => _$RosmPasswordLoginRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmWebAuthnLoginOptionsRequest {
  const RosmWebAuthnLoginOptionsRequest({this.email});

  final String? email;

  Map<String, dynamic> toJson() =>
      _$RosmWebAuthnLoginOptionsRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmPasswordRecoveryCodeRequest {
  const RosmPasswordRecoveryCodeRequest({
    required this.account,
    required this.method,
    required this.captchaToken,
  });

  final String account;
  @RosmPasswordRecoveryMethodConverter()
  final RosmPasswordRecoveryMethod method;
  final String captchaToken;

  Map<String, dynamic> toJson() =>
      _$RosmPasswordRecoveryCodeRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmPasswordResetByCodeRequest {
  const RosmPasswordResetByCodeRequest({
    required this.account,
    required this.method,
    required this.code,
    required this.newPassword,
  });

  final String account;
  @RosmPasswordRecoveryMethodConverter()
  final RosmPasswordRecoveryMethod method;
  final String code;
  final String newPassword;

  Map<String, dynamic> toJson() => _$RosmPasswordResetByCodeRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createFactory: false,
)
class RosmPasskeyRegistrationOptionsRequest {
  const RosmPasskeyRegistrationOptionsRequest({
    this.currentPassword,
    this.postRegisterBootstrap = false,
  });

  final String? currentPassword;
  final bool postRegisterBootstrap;

  Map<String, dynamic> toJson() =>
      _$RosmPasskeyRegistrationOptionsRequestToJson(this);
}

class RosmApiException implements Exception {
  const RosmApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return 'RosmApiException$status: $code: $message';
  }
}
