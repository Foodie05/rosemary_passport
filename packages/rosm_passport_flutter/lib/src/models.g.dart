// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$RosmAuthorizationRequestToJson(
  RosmAuthorizationRequest instance,
) => <String, dynamic>{
  'client_id': instance.clientId,
  'redirect_uri': const UriStringConverter().toJson(instance.redirectUri),
  'response_type': instance.responseType,
  'scope': instance.scope,
  'state': instance.state,
  'nonce': instance.nonce,
  'code_challenge': instance.codeChallenge,
  'code_challenge_method': instance.codeChallengeMethod,
  'server_handoff': instance.serverHandoff,
};

RosmNativeAuthorizationRequest _$RosmNativeAuthorizationRequestFromJson(
  Map<String, dynamic> json,
) => RosmNativeAuthorizationRequest(
  clientId: json['client_id'] as String,
  redirectUri: const UriStringConverter().fromJson(
    json['redirect_uri'] as String,
  ),
  responseType: json['response_type'] as String,
  scope: json['scope'] as String,
  state: json['state'] as String?,
  nonce: json['nonce'] as String?,
  codeChallenge: json['code_challenge'] as String?,
  codeChallengeMethod: json['code_challenge_method'] as String?,
  serverHandoff: json['server_handoff'] as bool? ?? false,
);

RosmAuthorizationStart _$RosmAuthorizationStartFromJson(
  Map<String, dynamic> json,
) => RosmAuthorizationStart(
  issuer: const UriStringConverter().fromJson(json['issuer'] as String),
  authorizationRequest: RosmNativeAuthorizationRequest.fromJson(
    json['authorization_request'] as Map<String, dynamic>,
  ),
  client: RosmClientInfo.fromJson(json['client'] as Map<String, dynamic>),
  scopes: (json['scopes'] as List<dynamic>)
      .map((e) => RosmScopeInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  pkceRequired: json['pkce_required'] as bool,
);

RosmAuthorizationApproval _$RosmAuthorizationApprovalFromJson(
  Map<String, dynamic> json,
) => RosmAuthorizationApproval(
  code: json['code'] as String,
  redirectUri: const UriStringConverter().fromJson(
    json['redirect_uri'] as String,
  ),
  callbackUrl: const UriStringConverter().fromJson(
    json['callback_url'] as String,
  ),
  state: json['state'] as String?,
);

RosmClientInfo _$RosmClientInfoFromJson(Map<String, dynamic> json) =>
    RosmClientInfo(
      clientId: json['client_id'] as String,
      displayName: json['display_name'] as String,
      isOfficial: json['is_official'] as bool,
      isConfidential: json['is_confidential'] as bool? ?? false,
    );

RosmScopeInfo _$RosmScopeInfoFromJson(Map<String, dynamic> json) =>
    RosmScopeInfo(
      name: json['name'] as String,
      description: json['description'] as String,
    );

RosmTokenSet _$RosmTokenSetFromJson(Map<String, dynamic> json) => RosmTokenSet(
  accessToken: json['access_token'] as String,
  refreshToken: json['refresh_token'] as String,
  tokenType: json['token_type'] as String,
  expiresIn: (json['expires_in'] as num).toInt(),
  idToken: json['id_token'] as String?,
);

Map<String, dynamic> _$RosmTokenSetToJson(RosmTokenSet instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
      'id_token': ?instance.idToken,
    };

RosmUser _$RosmUserFromJson(Map<String, dynamic> json) => RosmUser(
  id: json['id'] as String,
  email: json['email'] as String,
  nickname: json['nickname'] as String,
  roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
  phoneNumber: json['phone_number'] as String?,
  isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
);

RosmSecurityState _$RosmSecurityStateFromJson(Map<String, dynamic> json) =>
    RosmSecurityState(
      mustBindEmail: json['must_bind_email'] as bool? ?? false,
      adminMfaRequired: json['admin_mfa_required'] as bool? ?? false,
      hasPasskey: json['has_passkey'] as bool? ?? false,
      hasAuthenticator: json['has_authenticator'] as bool? ?? false,
      hasPhone: json['has_phone'] as bool? ?? false,
    );

RosmAuthResult _$RosmAuthResultFromJson(Map<String, dynamic> json) =>
    RosmAuthResult(
      user: RosmUser.fromJson(json['user'] as Map<String, dynamic>),
      security: RosmSecurityState.fromJson(
        json['security'] as Map<String, dynamic>,
      ),
      postRegisterPasskeyBootstrap:
          json['post_register_passkey_bootstrap'] as bool,
    );

RosmUserInfo _$RosmUserInfoFromJson(Map<String, dynamic> json) => RosmUserInfo(
  sub: json['sub'] as String,
  email: json['email'] as String?,
  emailVerified: json['email_verified'] as bool?,
  phoneNumber: json['phone_number'] as String?,
  phoneNumberVerified: json['phone_number_verified'] as bool?,
  name: json['name'] as String?,
  nickname: json['nickname'] as String?,
  roles:
      (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

RosmPasswordFactors _$RosmPasswordFactorsFromJson(Map<String, dynamic> json) =>
    RosmPasswordFactors(
      factors: (json['factors'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      directLogin: json['direct_login'] as bool,
      defaultFactor: json['default_factor'] as String?,
    );

RosmOperationResult _$RosmOperationResultFromJson(Map<String, dynamic> json) =>
    RosmOperationResult(
      sent: json['sent'] as bool? ?? false,
      updated: json['updated'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      message: json['message'] as String?,
    );

RosmWebAuthnCredentialInfo _$RosmWebAuthnCredentialInfoFromJson(
  Map<String, dynamic> json,
) => RosmWebAuthnCredentialInfo(
  credentialId: json['credential_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  deviceType: json['device_type'] as String?,
  backedUp: json['backed_up'] as bool? ?? false,
  transports:
      (json['transports'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

RosmPasskeyList _$RosmPasskeyListFromJson(Map<String, dynamic> json) =>
    RosmPasskeyList(
      credentials: (json['credentials'] as List<dynamic>)
          .map(
            (e) =>
                RosmWebAuthnCredentialInfo.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      maxCount: (json['max_count'] as num).toInt(),
    );

Map<String, dynamic> _$RosmPasswordFactorsRequestToJson(
  RosmPasswordFactorsRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
  'captcha_token': ?instance.captchaToken,
};

Map<String, dynamic> _$RosmPasswordLoginRequestToJson(
  RosmPasswordLoginRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
  'factor_type': ?instance.factorType,
  'email_code': ?instance.emailCode,
  'phone_code': ?instance.phoneCode,
  'authenticator_code': ?instance.authenticatorCode,
  'captcha_token': ?instance.captchaToken,
};

Map<String, dynamic> _$RosmWebAuthnLoginOptionsRequestToJson(
  RosmWebAuthnLoginOptionsRequest instance,
) => <String, dynamic>{'email': ?instance.email};

Map<String, dynamic> _$RosmPasswordRecoveryCodeRequestToJson(
  RosmPasswordRecoveryCodeRequest instance,
) => <String, dynamic>{
  'account': instance.account,
  'method': const RosmPasswordRecoveryMethodConverter().toJson(instance.method),
  'captcha_token': instance.captchaToken,
};

Map<String, dynamic> _$RosmPasswordResetByCodeRequestToJson(
  RosmPasswordResetByCodeRequest instance,
) => <String, dynamic>{
  'account': instance.account,
  'method': const RosmPasswordRecoveryMethodConverter().toJson(instance.method),
  'code': instance.code,
  'new_password': instance.newPassword,
};

Map<String, dynamic> _$RosmPasskeyRegistrationOptionsRequestToJson(
  RosmPasskeyRegistrationOptionsRequest instance,
) => <String, dynamic>{
  'current_password': ?instance.currentPassword,
  'post_register_bootstrap': instance.postRegisterBootstrap,
};
