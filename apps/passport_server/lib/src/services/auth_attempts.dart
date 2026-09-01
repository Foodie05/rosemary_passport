import '../models/authenticated_user.dart';
import '../security/token_service.dart';

class AuthResult {
  const AuthResult({
    required this.user,
    required this.tokens,
    this.postRegistrationPasskeyBootstrap = false,
  });

  final AuthenticatedUser user;
  final TokenPair tokens;
  final bool postRegistrationPasskeyBootstrap;
}

class LoginAttempt {
  const LoginAttempt.success(this.result)
    : code = null,
      message = null,
      statusCode = 200,
      registrationToken = null,
      stepUpChallenge = null,
      factors = const [];

  const LoginAttempt.registrationRequired(this.registrationToken)
    : result = null,
      code = 'registration_required',
      message = '验证成功，请完成注册。',
      statusCode = 409,
      stepUpChallenge = null,
      factors = const [];

  const LoginAttempt.mfaRequired({
    required this.stepUpChallenge,
    required this.factors,
  }) : result = null,
       code = 'mfa_required',
       message = '请选择另一种验证方式完成登录。',
       statusCode = 401,
       registrationToken = null;

  const LoginAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 401,
  }) : result = null,
       registrationToken = null,
       stepUpChallenge = null,
       factors = const [];

  final AuthResult? result;
  final String? code;
  final String? message;
  final int statusCode;
  final String? registrationToken;
  final String? stepUpChallenge;
  final List<String> factors;

  bool get ok => result != null;
}

class PasswordLoginPreparation {
  const PasswordLoginPreparation.success({
    required this.factors,
    required this.defaultFactor,
    this.directLogin = false,
  }) : ok = true,
       code = null,
       message = null,
       statusCode = 200;

  const PasswordLoginPreparation.failure({
    required this.code,
    required this.message,
    this.statusCode = 401,
  }) : ok = false,
       factors = const [],
       defaultFactor = null,
       directLogin = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final List<String> factors;
  final String? defaultFactor;
  final bool directLogin;
}

class AdminLoginCodeAttempt {
  const AdminLoginCodeAttempt.success({
    this.message,
    this.requiresBinding = false,
  }) : ok = true,
       code = null,
       statusCode = 200;

  const AdminLoginCodeAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       requiresBinding = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final bool requiresBinding;
}

class RegisterAttempt {
  const RegisterAttempt.success(this.result)
    : ok = true,
      code = null,
      message = null,
      statusCode = 201;

  const RegisterAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       result = null;

  final bool ok;
  final AuthResult? result;
  final String? code;
  final String? message;
  final int statusCode;
}

class AccountUpdateAttempt {
  const AccountUpdateAttempt.success({
    required this.updatedEmail,
    required this.updatedPassword,
    required this.updatedNickname,
  }) : ok = true,
       code = null,
       message = null,
       statusCode = 200;

  const AccountUpdateAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false,
       updatedEmail = false,
       updatedPassword = false,
       updatedNickname = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
  final bool updatedEmail;
  final bool updatedPassword;
  final bool updatedNickname;
}

class EmailActionAttempt {
  const EmailActionAttempt.success({this.message})
    : ok = true,
      code = null,
      statusCode = 200;

  const EmailActionAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
}

class CredentialActionAttempt {
  const CredentialActionAttempt.success({this.message})
    : ok = true,
      code = null,
      statusCode = 200;

  const CredentialActionAttempt.failure({
    required this.code,
    required this.message,
    this.statusCode = 400,
  }) : ok = false;

  final bool ok;
  final String? code;
  final String? message;
  final int statusCode;
}

class WebAuthnCredentialLimitException implements Exception {
  const WebAuthnCredentialLimitException();
}

class WebAuthnUnavailableException implements Exception {
  const WebAuthnUnavailableException();
}
