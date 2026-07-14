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
    http.Client? httpClient,
    RosmTokenStore? tokenStore,
  }) : scopes = Set.unmodifiable(scopes),
       _http = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? RosmSecureTokenStore();

  final Uri issuer;
  final String clientId;
  final Uri redirectUri;
  final Set<String> scopes;
  final http.Client _http;
  final RosmTokenStore _tokenStore;
  final Map<String, String> _cookies = {};

  RosmAuthorizationRequest createAuthorizationRequest({
    Set<String>? scopes,
    String? state,
    String? nonce,
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
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'code_verifier': request.codeVerifier,
    });
    final tokens = RosmTokenSet.fromJson(json);
    await _tokenStore.save(tokens);
    return tokens;
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

  Future<void> sendEmailLoginCode({
    required String email,
    String? captchaToken,
  }) async {
    await _postJson('/api/v1/auth/send-email-login-code', {
      'email': email,
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
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

  Future<void> sendPhoneLoginCode({
    required String phoneNumber,
    String? captchaToken,
  }) async {
    await _postJson('/api/v1/auth/send-phone-login-code', {
      'phone_number': phoneNumber,
      if (captchaToken != null) 'captcha_token': captchaToken,
    });
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

  Future<RosmWebAuthnOptions> beginWebAuthnLogin({String? email}) async {
    final json = await _postJson('/api/v1/auth/webauthn/options', {
      if (email != null) 'email': email,
    });
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

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _http.get(
      issuer.resolve(path),
      headers: {..._cookieHeader(), ...headers},
    );
    _storeCookies(response);
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    bool ignoreApiError = false,
  }) async {
    final response = await _http.post(
      issuer.resolve(path),
      headers: {'content-type': 'application/json', ..._cookieHeader()},
      body: jsonEncode(body),
    );
    _storeCookies(response);
    if (ignoreApiError && response.statusCode >= 400) {
      return const {};
    }
    return _decodeJsonResponse(response);
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
