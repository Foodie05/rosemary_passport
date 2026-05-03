import 'package:json_annotation/json_annotation.dart';

part 'auth_requests.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class PasswordFactorsRequest {
  const PasswordFactorsRequest({
    required this.email,
    required this.password,
    this.captchaToken,
  });

  factory PasswordFactorsRequest.fromJson(Map<String, dynamic> json) =>
      _$PasswordFactorsRequestFromJson(json);

  final String email;
  final String password;
  final String? captchaToken;

  Map<String, dynamic> toJson() => _$PasswordFactorsRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class PasswordLoginRequest {
  const PasswordLoginRequest({
    required this.email,
    required this.password,
    this.captchaToken,
    this.factorType,
    this.emailCode,
    this.authenticatorCode,
  });

  factory PasswordLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$PasswordLoginRequestFromJson(json);

  final String email;
  final String password;
  final String? captchaToken;
  final String? factorType;
  final String? emailCode;
  final String? authenticatorCode;

  Map<String, dynamic> toJson() => _$PasswordLoginRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class EmailLoginRequest {
  const EmailLoginRequest({
    required this.email,
    required this.emailCode,
  });

  factory EmailLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$EmailLoginRequestFromJson(json);

  final String email;
  final String emailCode;

  Map<String, dynamic> toJson() => _$EmailLoginRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class EmailRequest {
  const EmailRequest({
    required this.email,
    this.captchaToken,
  });

  factory EmailRequest.fromJson(Map<String, dynamic> json) =>
      _$EmailRequestFromJson(json);

  final String email;
  final String? captchaToken;

  Map<String, dynamic> toJson() => _$EmailRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class EmailPasswordRequest {
  const EmailPasswordRequest({
    required this.email,
    required this.password,
    this.captchaToken,
  });

  factory EmailPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$EmailPasswordRequestFromJson(json);

  final String email;
  final String password;
  final String? captchaToken;

  Map<String, dynamic> toJson() => _$EmailPasswordRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.nickname,
    required this.password,
    required this.emailCode,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);

  final String email;
  final String nickname;
  final String password;
  final String emailCode;

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class SendRegisterCodeRequest {
  const SendRegisterCodeRequest({
    required this.email,
    required this.captchaToken,
  });

  factory SendRegisterCodeRequest.fromJson(Map<String, dynamic> json) =>
      _$SendRegisterCodeRequestFromJson(json);

  final String email;
  final String captchaToken;

  Map<String, dynamic> toJson() => _$SendRegisterCodeRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class CaptchaRequest {
  const CaptchaRequest({
    required this.captchaToken,
  });

  factory CaptchaRequest.fromJson(Map<String, dynamic> json) =>
      _$CaptchaRequestFromJson(json);

  final String captchaToken;

  Map<String, dynamic> toJson() => _$CaptchaRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class RefreshRequest {
  const RefreshRequest({
    required this.refreshToken,
  });

  factory RefreshRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshRequestFromJson(json);

  final String refreshToken;

  Map<String, dynamic> toJson() => _$RefreshRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class WebAuthnOptionsRequest {
  const WebAuthnOptionsRequest({
    this.email,
  });

  factory WebAuthnOptionsRequest.fromJson(Map<String, dynamic> json) =>
      _$WebAuthnOptionsRequestFromJson(json);

  final String? email;

  Map<String, dynamic> toJson() => _$WebAuthnOptionsRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class WebAuthnVerifyRequest {
  const WebAuthnVerifyRequest({
    this.email,
    required this.response,
  });

  factory WebAuthnVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$WebAuthnVerifyRequestFromJson(json);

  final String? email;
  final Map<String, dynamic> response;

  Map<String, dynamic> toJson() => _$WebAuthnVerifyRequestToJson(this);
}
