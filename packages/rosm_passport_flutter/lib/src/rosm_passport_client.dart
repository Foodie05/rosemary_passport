import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'pkce.dart';
import 'rosm_aliyun_captcha.dart';
import 'rosm_passport_logger.dart';
import 'token_store.dart';

class RosmPassportClient {
  RosmPassportClient({
    required this.issuer,
    required this.clientId,
    required this.redirectUri,
    Set<String> scopes = const {'openid', 'profile', 'email'},
    http.Client? httpClient,
    RosmTokenStore? tokenStore,
    RosmLastSignInStore? lastSignInStore,
    RosmPassportLogger? logger,
  }) : scopes = Set.unmodifiable(scopes),
       _http = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? RosmSecureTokenStore(),
       _lastSignInStore = lastSignInStore ?? RosmSecureLastSignInStore(),
       logger = logger ?? RosmPassportLogging.logger;

  final Uri issuer;
  final String clientId;
  final Uri redirectUri;
  final Set<String> scopes;
  final RosmPassportLogger logger;
  final http.Client _http;
  final RosmTokenStore _tokenStore;
  final RosmLastSignInStore _lastSignInStore;
  final Map<String, String> _cookies = {};
  Future<RosmTokenSet>? _refreshInFlight;

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

  Future<RosmTokenSet> refresh() {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }

    late final Future<RosmTokenSet> pending;
    pending = _refreshFromStore().whenComplete(() {
      if (identical(_refreshInFlight, pending)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = pending;
    return pending;
  }

  Future<RosmTokenSet> _refreshFromStore() async {
    final current = await _tokenStore.read();
    final refreshToken = current?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const RosmApiException(
        'missing_refresh_token',
        'No refresh token is available.',
      );
    }
    return _refreshWithToken(refreshToken);
  }

  Future<RosmUserInfo> userInfo() async {
    final json = await _getJson('/oidc/userinfo');
    return RosmUserInfo.fromJson(json);
  }

  Future<RosmAccountState> account() async {
    final json = await _getJson('/api/v1/me');
    return RosmAccountState.fromJson(json);
  }

  /// Reads the public Aliyun Captcha 2.0 configuration from the ROSM issuer.
  /// No Aliyun secret is ever returned to or stored by the application.
  Future<RosmAliyunCaptchaConfig?> aliyunCaptchaConfig() async {
    final json = await _getJson('/api/v1/public/config');
    final captcha = json['captcha'];
    if (captcha is! Map) return null;
    if ((captcha['provider'] ?? '').toString().trim().toLowerCase() !=
        'aliyun') {
      return null;
    }
    final config = RosmAliyunCaptchaConfig.fromJson(
      Map<String, dynamic>.from(captcha),
    );
    return config.isConfigured ? config : null;
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
    await _lastSignInStore.clear();
  }

  Future<RosmLastSignIn?> lastSignIn() => _lastSignInStore.read();

  Future<void> clearLastSignIn() => _lastSignInStore.clear();

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
    return _authResultFromJson(
      json,
      lastSignIn: RosmLastSignIn(
        method: RosmSignInMethod.password,
        identifier: email.trim(),
      ),
    );
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
    String? password,
  }) async {
    final json = await _postJson('/api/v1/auth/email-login', {
      'email': email,
      'email_code': emailCode,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return _authResultFromJson(
      json,
      lastSignIn: RosmLastSignIn(
        method: RosmSignInMethod.emailCode,
        identifier: email.trim(),
      ),
    );
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
    return _authResultFromJson(
      json,
      lastSignIn: RosmLastSignIn(
        method: RosmSignInMethod.phoneCode,
        identifier: phoneNumber.trim(),
      ),
    );
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
    String? emailCode,
    String? registrationHandoff,
  }) async {
    final json = await _postJson(
      '/api/v1/auth/register',
      RosmEmailRegisterRequest(
        email: email,
        nickname: nickname,
        password: password,
        emailCode: emailCode,
        registrationHandoff: registrationHandoff,
      ).toJson(),
    );
    return _authResultFromJson(json);
  }

  Future<RosmAuthResult> registerWithPhone({
    required String phoneNumber,
    required String nickname,
    required String password,
    String? verifyCode,
    String? registrationHandoff,
  }) async {
    final json = await _postJson('/api/v1/auth/register-phone', {
      'phone_number': phoneNumber,
      'nickname': nickname,
      'password': password,
      if (verifyCode != null && verifyCode.isNotEmpty)
        'verify_code': verifyCode,
      if (registrationHandoff != null && registrationHandoff.isNotEmpty)
        'registration_handoff': registrationHandoff,
    });
    return _authResultFromJson(json);
  }

  Future<RosmOperationResult> sendLoginStepUpCode({
    required String challenge,
    required String factor,
  }) async {
    final json = await _postJson('/api/v1/auth/login-step-up-code', {
      'step_up_challenge': challenge,
      'factor': factor,
    });
    return RosmOperationResult.fromJson(json);
  }

  Future<Map<String, dynamic>> loginStepUpPasskeyOptions({
    required String challenge,
  }) => _postJson('/api/v1/auth/login-step-up-passkey-options', {
    'step_up_challenge': challenge,
  });

  Future<RosmAuthResult> completeLoginStepUp({
    required String challenge,
    required String factor,
    String? password,
    String? code,
    Map<String, dynamic>? response,
  }) async {
    final json = await _postJson('/api/v1/auth/login-step-up', {
      'step_up_challenge': challenge,
      'factor': factor,
      if (password != null) 'password': password,
      if (code != null) 'code': code,
      if (response != null) 'response': response,
    });
    return _authResultFromJson(json);
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

  Future<RosmAuthResult> _authResultFromJson(
    Map<String, dynamic> json, {
    RosmLastSignIn? lastSignIn,
  }) async {
    final result = RosmAuthResult.fromJson(json);
    final tokens = result.tokens;
    if (tokens != null) {
      await _tokenStore.save(tokens);
    }
    if (lastSignIn != null && lastSignIn.identifier.isNotEmpty) {
      await _lastSignInStore.save(lastSignIn);
    }
    return result;
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

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String> headers = const {},
    bool retryOnUnauthorized = true,
  }) async {
    final uri = issuer.resolve(path);
    final stopwatch = _startHttpLog('GET', uri);
    try {
      var response = await _http.get(
        uri,
        headers: {...await _authHeaders(), ...headers},
      );
      _storeCookies(response);
      if (retryOnUnauthorized &&
          response.statusCode == 401 &&
          await _refreshAfterUnauthorized()) {
        response = await _http.get(
          uri,
          headers: {...await _authHeaders(), ...headers},
        );
        _storeCookies(response);
      }
      final json = _decodeJsonResponse(response);
      _finishHttpLog('GET', uri, response.statusCode, stopwatch);
      return json;
    } on Object catch (error, stackTrace) {
      _failHttpLog('GET', uri, stopwatch, error, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
    bool ignoreApiError = false,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = issuer.resolve(path);
    final stopwatch = _startHttpLog('POST', uri);
    try {
      var response = await _http.post(
        uri,
        headers: {
          'content-type': 'application/json',
          ...await _authHeaders(),
          ...headers,
        },
        body: jsonEncode(body),
      );
      _storeCookies(response);
      if (retryOnUnauthorized &&
          response.statusCode == 401 &&
          await _refreshAfterUnauthorized()) {
        response = await _http.post(
          uri,
          headers: {
            'content-type': 'application/json',
            ...await _authHeaders(),
            ...headers,
          },
          body: jsonEncode(body),
        );
        _storeCookies(response);
      }
      if (ignoreApiError && response.statusCode >= 400) {
        _finishHttpLog('POST', uri, response.statusCode, stopwatch);
        return const {};
      }
      final json = _decodeJsonResponse(response);
      _finishHttpLog('POST', uri, response.statusCode, stopwatch);
      return json;
    } on Object catch (error, stackTrace) {
      _failHttpLog('POST', uri, stopwatch, error, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
    bool retryOnUnauthorized = true,
  }) async {
    final uri = issuer.resolve(path);
    final stopwatch = _startHttpLog('PATCH', uri);
    try {
      var response = await _http.patch(
        uri,
        headers: {
          'content-type': 'application/json',
          ...await _authHeaders(),
          ...headers,
        },
        body: jsonEncode(body),
      );
      _storeCookies(response);
      if (retryOnUnauthorized &&
          response.statusCode == 401 &&
          await _refreshAfterUnauthorized()) {
        response = await _http.patch(
          uri,
          headers: {
            'content-type': 'application/json',
            ...await _authHeaders(),
            ...headers,
          },
          body: jsonEncode(body),
        );
        _storeCookies(response);
      }
      final json = _decodeJsonResponse(response);
      _finishHttpLog('PATCH', uri, response.statusCode, stopwatch);
      return json;
    } on Object catch (error, stackTrace) {
      _failHttpLog('PATCH', uri, stopwatch, error, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postAbsoluteJson(
    Uri endpoint,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final stopwatch = _startHttpLog('POST', endpoint);
    try {
      final response = await _http.post(
        endpoint,
        headers: {'content-type': 'application/json', ...headers},
        body: jsonEncode(body),
      );
      final json = _decodeJsonResponse(response);
      _finishHttpLog('POST', endpoint, response.statusCode, stopwatch);
      return json;
    } on Object catch (error, stackTrace) {
      _failHttpLog('POST', endpoint, stopwatch, error, stackTrace);
      rethrow;
    }
  }

  Stopwatch _startHttpLog(String method, Uri uri) {
    logger.debug(
      'HTTP request started.',
      source: 'rosm_passport.client',
      event: 'http.request',
      context: {'method': method, 'path': uri.path},
    );
    return Stopwatch()..start();
  }

  void _finishHttpLog(
    String method,
    Uri uri,
    int statusCode,
    Stopwatch stopwatch,
  ) {
    stopwatch.stop();
    final context = {
      'method': method,
      'path': uri.path,
      'status_code': statusCode,
      'duration_ms': stopwatch.elapsedMilliseconds,
    };
    final message = statusCode >= 400
        ? 'HTTP request failed.'
        : 'HTTP request completed.';
    if (statusCode >= 400) {
      logger.warning(
        message,
        source: 'rosm_passport.client',
        event: 'http.response',
        context: context,
      );
    } else {
      logger.info(
        message,
        source: 'rosm_passport.client',
        event: 'http.response',
        context: context,
      );
    }
  }

  void _failHttpLog(
    String method,
    Uri uri,
    Stopwatch stopwatch,
    Object error,
    StackTrace stackTrace,
  ) {
    stopwatch.stop();
    final context = {
      'method': method,
      'path': uri.path,
      'duration_ms': stopwatch.elapsedMilliseconds,
      if (error is RosmApiException) 'error_code': error.code,
      if (error is RosmApiException && error.statusCode != null)
        'status_code': error.statusCode,
    };
    logger.error(
      'HTTP request threw an error.',
      source: 'rosm_passport.client',
      event: 'http.error',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<bool> _refreshAfterUnauthorized() async {
    final refreshToken = (await _tokenStore.read())?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      await refresh();
      logger.info(
        'Access token refreshed after unauthorized response.',
        source: 'rosm_passport.client',
        event: 'auth.refresh.success',
      );
      return true;
    } on Object catch (error, stackTrace) {
      await _tokenStore.clear();
      logger.warning(
        'Token refresh failed after unauthorized response.',
        source: 'rosm_passport.client',
        event: 'auth.refresh.failure',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<RosmTokenSet> _refreshWithToken(String refreshToken) async {
    final uri = issuer.resolve('/oidc/token');
    final stopwatch = _startHttpLog('POST', uri);
    try {
      final response = await _http.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        }),
      );
      final json = _decodeJsonResponse(response);
      _finishHttpLog('POST', uri, response.statusCode, stopwatch);
      final tokens = RosmTokenSet.fromJson(json);
      await _tokenStore.save(tokens);
      return tokens;
    } on Object catch (error, stackTrace) {
      _failHttpLog('POST', uri, stopwatch, error, stackTrace);
      rethrow;
    }
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    final json = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode >= 400) {
      final error = json['error']?.toString();
      final message = json['message']?.toString();
      throw RosmApiException(
        error ?? 'request_failed',
        message == null || message.isEmpty
            ? _fallbackMessageFor(error, response)
            : message,
        statusCode: response.statusCode,
        details: json,
      );
    }
    return json;
  }

  String _fallbackMessageFor(String? error, http.Response response) {
    final normalized = error?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return switch (normalized) {
        'invalid state' || 'invalid_state' => '授权会话已失效，请重新登录后再试。',
        'state expired' || 'state_expired' => '授权会话已过期，请重新登录后再试。',
        'state already consumed' ||
        'state_already_consumed' => '这次授权已经处理过，请重新发起登录。',
        'authorization challenge mismatch' ||
        'authorization_challenge_mismatch' => '授权请求与服务器记录不一致，请重新登录后再试。',
        'missing required handoff fields' ||
        'missing_required_handoff_fields' => '应用服务器接入参数不完整，请检查 SDK 接入配置。',
        'oidc client not configured' ||
        'oidc_client_not_configured' => '应用服务器尚未正确配置 ROSM OIDC 客户端。',
        'unauthorized' ||
        'missing_access_token' ||
        'invalid_access_token' => '登录状态已过期，请重新登录。',
        'invalid_grant' => '登录凭据已失效，请重新登录。',
        _ => normalized,
      };
    }
    return response.reasonPhrase ?? 'Request failed.';
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
