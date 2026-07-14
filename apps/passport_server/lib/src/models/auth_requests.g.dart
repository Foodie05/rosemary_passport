// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_requests.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PasswordFactorsRequest _$PasswordFactorsRequestFromJson(
  Map<String, dynamic> json,
) => PasswordFactorsRequest(
  email: json['email'] as String,
  password: json['password'] as String,
  captchaToken: json['captcha_token'] as String?,
);

Map<String, dynamic> _$PasswordFactorsRequestToJson(
  PasswordFactorsRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
  'captcha_token': ?instance.captchaToken,
};

PasswordLoginRequest _$PasswordLoginRequestFromJson(
  Map<String, dynamic> json,
) => PasswordLoginRequest(
  email: json['email'] as String,
  password: json['password'] as String,
  captchaToken: json['captcha_token'] as String?,
  factorType: json['factor_type'] as String?,
  emailCode: json['email_code'] as String?,
  phoneCode: json['phone_code'] as String?,
  authenticatorCode: json['authenticator_code'] as String?,
);

Map<String, dynamic> _$PasswordLoginRequestToJson(
  PasswordLoginRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
  'captcha_token': ?instance.captchaToken,
  'factor_type': ?instance.factorType,
  'email_code': ?instance.emailCode,
  'phone_code': ?instance.phoneCode,
  'authenticator_code': ?instance.authenticatorCode,
};

EmailLoginRequest _$EmailLoginRequestFromJson(Map<String, dynamic> json) =>
    EmailLoginRequest(
      email: json['email'] as String,
      emailCode: json['email_code'] as String,
    );

Map<String, dynamic> _$EmailLoginRequestToJson(EmailLoginRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'email_code': instance.emailCode,
    };

EmailRequest _$EmailRequestFromJson(Map<String, dynamic> json) => EmailRequest(
  email: json['email'] as String,
  captchaToken: json['captcha_token'] as String?,
);

Map<String, dynamic> _$EmailRequestToJson(EmailRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'captcha_token': ?instance.captchaToken,
    };

EmailPasswordRequest _$EmailPasswordRequestFromJson(
  Map<String, dynamic> json,
) => EmailPasswordRequest(
  email: json['email'] as String,
  password: json['password'] as String,
  captchaToken: json['captcha_token'] as String?,
);

Map<String, dynamic> _$EmailPasswordRequestToJson(
  EmailPasswordRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
  'captcha_token': ?instance.captchaToken,
};

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      password: json['password'] as String,
      emailCode: json['email_code'] as String,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'nickname': instance.nickname,
      'password': instance.password,
      'email_code': instance.emailCode,
    };

SendRegisterCodeRequest _$SendRegisterCodeRequestFromJson(
  Map<String, dynamic> json,
) => SendRegisterCodeRequest(
  email: json['email'] as String,
  captchaToken: json['captcha_token'] as String,
);

Map<String, dynamic> _$SendRegisterCodeRequestToJson(
  SendRegisterCodeRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'captcha_token': instance.captchaToken,
};

CaptchaRequest _$CaptchaRequestFromJson(Map<String, dynamic> json) =>
    CaptchaRequest(captchaToken: json['captcha_token'] as String);

Map<String, dynamic> _$CaptchaRequestToJson(CaptchaRequest instance) =>
    <String, dynamic>{'captcha_token': instance.captchaToken};

RefreshRequest _$RefreshRequestFromJson(Map<String, dynamic> json) =>
    RefreshRequest(refreshToken: json['refresh_token'] as String);

Map<String, dynamic> _$RefreshRequestToJson(RefreshRequest instance) =>
    <String, dynamic>{'refresh_token': instance.refreshToken};

WebAuthnOptionsRequest _$WebAuthnOptionsRequestFromJson(
  Map<String, dynamic> json,
) => WebAuthnOptionsRequest(email: json['email'] as String?);

Map<String, dynamic> _$WebAuthnOptionsRequestToJson(
  WebAuthnOptionsRequest instance,
) => <String, dynamic>{'email': ?instance.email};

WebAuthnVerifyRequest _$WebAuthnVerifyRequestFromJson(
  Map<String, dynamic> json,
) => WebAuthnVerifyRequest(
  email: json['email'] as String?,
  response: json['response'] as Map<String, dynamic>,
);

Map<String, dynamic> _$WebAuthnVerifyRequestToJson(
  WebAuthnVerifyRequest instance,
) => <String, dynamic>{'email': ?instance.email, 'response': instance.response};
