import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'pkce.dart';
import 'token_store.dart';

class RosmPassportClient {
  RosmPassportClient({
    required this.issuer,
    required this.clientId,
    required this.redirectUri,
    Set<String> scopes = const {'openid', 'profile', 'email'},
    Uri? webAuthnOrigin,
    http.Client? httpClient,
    RosmTokenStore? tokenStore,
  }) : scopes = Set.unmodifiable(scopes),
       webAuthnOrigin =
           webAuthnOrigin ?? issuer.replace(path: '', query: '', fragment: ''),
       _http = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? RosmSecureTokenStore();

  final Uri issuer;
  final String clientId;
  final Uri redirectUri;
  final Set<String> scopes;
  final Uri webAuthnOrigin;
  final http.Client _http;
  final RosmTokenStore _tokenStore;
  final Map<String, String> _cookies = {};

  RosmAuthorizationRequest createAuthorizationRequest({
    Set<String>? scopes,
    String? state,
    String? nonce,
    bool serverHandoff = false,
  }) {
    final codeVerifier = randomUrlSafeString(64);
    return RosmAuthorizationRequest(
      clientId: clientId,
      redirectUri: redirectUri,
      responseType: 'code',
      scope: (scopes ?? this.scopes).join(' '),
      state: state ?? randomUrlSafeString(32),
      nonce: nonce ?? randomUrlSafeString(32),
      codeVerifier: codeVerifier,
      codeChallenge: s256Challenge(codeVerifier),
      codeChallengeMethod: 'S256',
      serverHandoff: serverHandoff,
    );
  }

  Future<RosmAuthorizationStart> startNativeAuthorization(
    RosmAuthorizationRequest request,
  ) async {
    final json = await _postJson('/api/v1/oidc/native/start', request.toJson());
    return RosmAuthorizationStart.fromJson(json);
  }

  Future<RosmAuthorizationApproval> approveNativeAuthorization(
    RosmAuthorizationRequest request,
  ) async {
    final json = await _postJson(
      '/api/v1/oidc/native/approve',
      request.toJson(),
    );
    final approval = RosmAuthorizationApproval.fromJson(json);
    if (approval.state != request.state) {
      throw const RosmApiException(
        'invalid_state',
        'Authorization response state did not match the request.',
      );
    }
    return approval;
  }

  Future<void> cancelNativeAuthorization(
    RosmAuthorizationRequest request,
  ) async {
    await _postJson('/api/v1/oidc/native/cancel', request.toJson());
  }

  Future<RosmTokenSet> exchangeCode({
    required RosmAuthorizationRequest request,
    required RosmAuthorizationApproval approval,
  }) async {
    final json = await _postJson('/oidc/token', {
      'grant_type': 'authorization_code',
      'code': approval.code,
      'client_id': request.clientId,
      'redirect_uri': request.redirectUri.toString(),
      'code_verifier': request.codeVerifier,
    });
    final tokens = RosmTokenSet.fromJson(json);
    await _tokenStore.save(tokens);
    return tokens;
  }

  Future<RosmServerHandoffResult> completeServerHandoff({
    required Uri endpoint,
    required RosmAuthorizationRequest request,
    required RosmAuthorizationApproval approval,
    Map<String, String> headers = const {},
    Map<String, Object?> extra = const {},
  }) async {
    if (!request.serverHandoff) {
      throw const RosmApiException(
        'server_handoff_required',
        'Create the authorization request with serverHandoff: true.',
      );
    }
    if (approval.state != request.state) {
      throw const RosmApiException(
        'invalid_state',
        'Authorization response state did not match the request.',
      );
    }
    final json = await _postAbsoluteJson(endpoint, {
      'issuer': issuer.toString(),
      'client_id': request.clientId,
      'redirect_uri': request.redirectUri.toString(),
      'code': approval.code,
      'state': approval.state,
      'callback_url': approval.callbackUrl.toString(),
      'code_verifier': request.codeVerifier,
      'scope': request.scope,
      'nonce': request.nonce,
      if (extra.isNotEmpty) 'extra': extra,
    }, headers: headers);
    return RosmServerHandoffResult(authorization: approval, payload: json);
  }

  Future<RosmTokenSet> refresh() async {
    final current = await _tokenStore.read();
    final refreshToken = current?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const RosmApiException(
        'missing_refresh_token',
        'No refresh token is available.',
      );
    }
    final json = await _postJson('/oidc/token', {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
    });
    final tokens = RosmTokenSet.fromJson(json);
    await _tokenStore.save(tokens);
    return tokens;
  }

  Future<RosmUserInfo> userInfo() async {
    final tokens = await _tokenStore.read();
    final accessToken = tokens?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const RosmApiException(
        'missing_access_token',
        'No access token is available.',
      );
    }
    final json = await _getJson(
      '/oidc/userinfo',
      headers: {'authorization': 'Bearer $accessToken'},
    );
    return RosmUserInfo.fromJson(json);
  }

  Future<RosmAccountState> account() async {
    final json = await _getJson('/api/v1/me');
    return RosmAccountState.fromJson(json);
  }

  Future<RosmOperationResult> updateAccount({
    String? nickname,
    String? currentPassword,
    String? newEmail,
    String? newPassword,
  }) async {
    final json = await _patchJson('/api/v1/me', {
      if (nickname != null) 'nickname': nickname,
      if (currentPassword != null) 'current_password': currentPassword,
      if (newEmail != null) 'email': newEmail,
      if (newPassword != null) 'new_password': newPassword,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> sendBindEmailCode({
    required String email,
    required String currentPassword,
    String? captchaToken,
  }) async {
    final json = await _postJson('/api/v1/me/send-bind-email-code', {
      'email': email,
      'current_password': currentPassword,
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> bindEmail({
    required String email,
    required String currentPassword,
    required String emailCode,
  }) async {
    final json = await _postJson('/api/v1/me/bind-email', {
      'email': email,
      'current_password': currentPassword,
      'email_code': emailCode,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> sendBindPhoneCode({
    required String phoneNumber,
    required String currentPassword,
    String? captchaToken,
  }) async {
    final json = await _postJson('/api/v1/me/send-bind-phone-code', {
      'phone_number': phoneNumber,
      'current_password': currentPassword,
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> bindPhone({
    required String phoneNumber,
    required String currentPassword,
    required String verifyCode,
  }) async {
    final json = await _postJson('/api/v1/me/bind-phone', {
      'phone_number': phoneNumber,
      'current_password': currentPassword,
      'verify_code': verifyCode,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> sendOwnPasswordResetCode({
    String? captchaToken,
  }) async {
    final json = await _postJson('/api/v1/me/send-password-reset-code', {
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> resetOwnPassword({
    required String newPassword,
    required String emailCode,
  }) async {
    final json = await _postJson('/api/v1/me/reset-password', {
      'new_password': newPassword,
      'email_code': emailCode,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmAuthenticatorSetup> beginAuthenticatorSetup({
    required String currentPassword,
  }) async {
    final json = await _postJson('/api/v1/me/authenticator/setup', {
      'current_password': currentPassword,
    });
    return RosmAuthenticatorSetup.fromJson(json);
  }

  Future<RosmOperationResult> verifyAuthenticatorSetup({
    required String currentPassword,
    required String secret,
    required String code,
  }) async {
    final json = await _postJson('/api/v1/me/authenticator/verify', {
      'current_password': currentPassword,
      'secret': secret,
      'code': code,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<void> signOut() async {
    final tokens = await _tokenStore.read();
    if (tokens != null) {
      await _postJson('/oidc/revoke', {
        'token': tokens.refreshToken,
        'client_id': clientId,
      }, ignoreApiError: true);
    }
    _cookies.clear();
    await _tokenStore.clear();
  }

  Future<RosmPasswordFactors> passwordFactors({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/password-factors',
      RosmPasswordFactorsRequest(
        email: email,
        password: password,
        captchaToken: captchaToken,
      ).toJson(),
    );
    return RosmPasswordFactors.fromJson(json);
  }

  Future<RosmAuthResult> loginWithPassword({
    required String email,
    required String password,
    String? factorType,
    String? emailCode,
    String? phoneCode,
    String? authenticatorCode,
    String? captchaToken,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/login',
      RosmPasswordLoginRequest(
        email: email,
        password: password,
        factorType: factorType,
        emailCode: emailCode,
        phoneCode: phoneCode,
        authenticatorCode: authenticatorCode,
        captchaToken: captchaToken,
      ).toJson(),
    );
    return RosmAuthResult.fromJson(json);
  }

  Future<RosmOperationResult> sendPasswordMfaCode({
    required String email,
    required String password,
    required String factorType,
    String? captchaToken,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/send-login-code',
      RosmPasswordLoginRequest(
        email: email,
        password: password,
        factorType: factorType,
        captchaToken: captchaToken,
      ).toJson(),
    );
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> sendEmailLoginCode({
    required String email,
    String? captchaToken,
  }) async {
    final json = await _postJson('/api/v1/auth/send-email-login-code', {
      'email': email,
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmAuthResult> loginWithEmailCode({
    required String email,
    required String emailCode,
  }) async {
    final json = await _postJson('/api/v1/auth/email-login', {
      'email': email,
      'email_code': emailCode,
    });
    return RosmAuthResult.fromJson(json);
  }

  Future<RosmOperationResult> sendPhoneLoginCode({
    required String phoneNumber,
    String? captchaToken,
  }) async {
    final json = await _postJson('/api/v1/auth/send-phone-login-code', {
      'phone_number': phoneNumber,
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmAuthResult> loginWithPhoneCode({
    required String phoneNumber,
    required String verifyCode,
  }) async {
    final json = await _postJson('/api/v1/auth/phone-login', {
      'phone_number': phoneNumber,
      'verify_code': verifyCode,
    });
    return RosmAuthResult.fromJson(json);
  }

  Future<RosmOperationResult> sendRegisterCode({
    required String email,
    required String captchaToken,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/send-code',
      RosmRegisterCodeRequest(
        email: email,
        captchaToken: captchaToken,
      ).toJson(),
    );
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmAuthResult> registerWithEmail({
    required String email,
    required String nickname,
    required String password,
    required String emailCode,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/register',
      RosmEmailRegisterRequest(
        email: email,
        nickname: nickname,
        password: password,
        emailCode: emailCode,
      ).toJson(),
    );
    return RosmAuthResult.fromJson(json);
  }

  Future<RosmWebAuthnOptions> beginWebAuthnLogin({
    String? email,
    Uri? origin,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/webauthn/options',
      RosmWebAuthnLoginOptionsRequest(email: email).toJson(),
      headers: _webAuthnHeaders(origin),
    );
    return RosmWebAuthnOptions.fromJson(json);
  }

  Future<RosmAuthResult> completeWebAuthnLogin({
    String? email,
    required RosmWebAuthnCredential credential,
  }) async {
    final json = await _postJson('/api/v1/auth/webauthn/verify', {
      if (email != null) 'email': email,
      'response': credential.response,
    });
    return RosmAuthResult.fromJson(json);
  }

  Future<RosmOperationResult> sendPasswordRecoveryCode({
    required String account,
    required RosmPasswordRecoveryMethod method,
    required String captchaToken,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/send-recovery-code',
      RosmPasswordRecoveryCodeRequest(
        account: account,
        method: method,
        captchaToken: captchaToken,
      ).toJson(),
    );
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmOperationResult> resetPasswordByCode({
    required String account,
    required RosmPasswordRecoveryMethod method,
    required String code,
    required String newPassword,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/reset-password-by-code',
      RosmPasswordResetByCodeRequest(
        account: account,
        method: method,
        code: code,
        newPassword: newPassword,
      ).toJson(),
    );
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmWebAuthnOptions> beginPasskeyRegistration({
    String? currentPassword,
    bool postRegisterBootstrap = false,
    Uri? origin,
  }) async {
    final json = await _postJson(
      '/api/v1/me/webauthn/register/options',
      RosmPasskeyRegistrationOptionsRequest(
        currentPassword: currentPassword,
        postRegisterBootstrap: postRegisterBootstrap,
      ).toJson(),
      headers: _webAuthnHeaders(origin),
    );
    return RosmWebAuthnOptions.fromJson(json);
  }

  Future<RosmOperationResult> completePasskeyRegistration({
    required RosmWebAuthnCredential credential,
  }) async {
    final json = await _postJson('/api/v1/me/webauthn/register/verify', {
      'response': credential.response,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<RosmPasskeyList> listPasskeys() async {
    final json = await _getJson('/api/v1/me/webauthn/credentials');
    return RosmPasskeyList.fromJson(json);
  }

  Future<RosmOperationResult> deletePasskey(String credentialId) async {
    final json = await _deleteJson(
      '/api/v1/me/webauthn/credentials/${Uri.encodeComponent(credentialId)}',
    );
    return RosmOperationResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _http.get(
      issuer.resolve(path),
      headers: {...await _authHeaders(), ...headers},
    );
    _storeCookies(response);
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
    bool ignoreApiError = false,
  }) async {
    final response = await _http.post(
      issuer.resolve(path),
      headers: {
        'content-type': 'application/json',
        ...await _authHeaders(),
        ...headers,
      },
      body: jsonEncode(body),
    );
    _storeCookies(response);
    if (ignoreApiError && response.statusCode >= 400) {
      return const {};
    }
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _http.patch(
      issuer.resolve(path),
      headers: {
        'content-type': 'application/json',
        ...await _authHeaders(),
        ...headers,
      },
      body: jsonEncode(body),
    );
    _storeCookies(response);
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _postAbsoluteJson(
    Uri endpoint,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _http.post(
      endpoint,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    );
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final response = await _http.delete(
      issuer.resolve(path),
      headers: await _authHeaders(),
    );
    _storeCookies(response);
    return _decodeJsonResponse(response);
  }

  Map<String, String> _webAuthnHeaders(Uri? origin) {
    return {'origin': (origin ?? webAuthnOrigin).toString()};
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    final json = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw RosmApiException(
        json['error']?.toString() ?? 'request_failed',
        json['message']?.toString() ??
            response.reasonPhrase ??
            'Request failed.',
        statusCode: response.statusCode,
      );
    }
    return json;
  }

  Map<String, String> _cookieHeader() {
    if (_cookies.isEmpty) {
      return const {};
    }
    return {
      'cookie': _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; '),
    };
  }

  Future<Map<String, String>> _authHeaders() async {
    final cookies = _cookieHeader();
    final token = (await _tokenStore.read())?.accessToken;
    return {
      ...cookies,
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  void _storeCookies(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.trim().isEmpty) {
      return;
    }
    for (final cookie in setCookie.split(',')) {
      final segment = cookie.split(';').first.trim();
      final index = segment.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final name = segment.substring(0, index);
      final value = segment.substring(index + 1);
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }
}
