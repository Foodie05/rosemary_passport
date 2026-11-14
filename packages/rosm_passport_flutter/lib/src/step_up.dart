/// A per-operation proof. The server chooses eligible bound factors and verifies
/// the current user; clients must never cache a successful-verification flag.
class RosmStepUpProof {
  const RosmStepUpProof.password(String value)
    : method = 'password',
      _password = value,
      _code = null,
      _response = null;
  const RosmStepUpProof.emailCode(String value)
    : method = 'email_code',
      _password = null,
      _code = value,
      _response = null;
  const RosmStepUpProof.phoneCode(String value)
    : method = 'phone_code',
      _password = null,
      _code = value,
      _response = null;
  const RosmStepUpProof.authenticator(String value)
    : method = 'authenticator',
      _password = null,
      _code = value,
      _response = null;
  const RosmStepUpProof.passkey(Map<String, dynamic> response)
    : method = 'passkey',
      _password = null,
      _code = null,
      _response = response;
  final String method;
  final String? _password, _code;
  final Map<String, dynamic>? _response;
  Map<String, dynamic> toJson() => {
    'method': method,
    if (_password != null) 'password': _password,
    if (_code != null) 'code': _code,
    if (_response != null) 'response': Map<String, dynamic>.from(_response),
  };
}
