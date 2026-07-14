import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'rosm_native_passkeys.dart';
import 'rosm_passport_client.dart';

typedef RosmCaptchaTokenProvider = Future<String?> Function();
typedef RosmPasskeyAuthenticator =
    Future<RosmWebAuthnCredential> Function(RosmWebAuthnOptions options);

class RosmPassportSignInConfig {
  const RosmPassportSignInConfig({
    this.serverHandoffEndpoint,
    this.serverHandoffHeaders = const {},
    this.serverHandoffExtra = const {},
    this.state,
    this.nonce,
    this.requestCaptchaToken,
    this.authenticatePasskey,
    this.enableEmailCode = true,
    this.enablePhoneCode = true,
    this.enablePassword = true,
    this.enablePasskey = true,
    this.enableRegistration = true,
  });

  final Uri? serverHandoffEndpoint;
  final Map<String, String> serverHandoffHeaders;
  final Map<String, Object?> serverHandoffExtra;
  final String? state;
  final String? nonce;
  final RosmCaptchaTokenProvider? requestCaptchaToken;
  final RosmPasskeyAuthenticator? authenticatePasskey;
  final bool enableEmailCode;
  final bool enablePhoneCode;
  final bool enablePassword;
  final bool enablePasskey;
  final bool enableRegistration;
}

class RosmPassportUiResult {
  const RosmPassportUiResult({
    required this.auth,
    required this.authorization,
    this.tokens,
    this.serverPayload,
  });

  final RosmAuthResult auth;
  final RosmAuthorizationApproval authorization;
  final RosmTokenSet? tokens;
  final Map<String, dynamic>? serverPayload;
}

Future<RosmPassportUiResult?> showRosmPassportSignIn(
  BuildContext context, {
  required RosmPassportClient client,
  RosmPassportSignInConfig config = const RosmPassportSignInConfig(),
}) {
  return Navigator.of(context).push<RosmPassportUiResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RosmPassportSignInPage(client: client, config: config),
    ),
  );
}

class RosmPassportSignInPage extends StatefulWidget {
  const RosmPassportSignInPage({
    required this.client,
    this.config = const RosmPassportSignInConfig(),
    super.key,
  });

  final RosmPassportClient client;
  final RosmPassportSignInConfig config;

  @override
  State<RosmPassportSignInPage> createState() => _RosmPassportSignInPageState();
}

class _RosmPassportSignInPageState extends State<RosmPassportSignInPage> {
  static final _logoUri = Uri.parse(
    'https://tianyue.s3.bitiful.net/logo/rosemary_pure.png',
  );

  late final RosmAuthorizationRequest _request;
  RosmAuthorizationStart? _start;
  RosmAuthResult? _pendingAuth;
  var _mode = _SignInMode.phone;
  var _loading = true;
  var _busy = false;
  var _sent = false;
  String? _error;

  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _passwordEmail = TextEditingController();
  final _password = TextEditingController();
  final _mfaCode = TextEditingController();
  final _code = TextEditingController();
  final _recoveryAccount = TextEditingController();
  final _recoveryCode = TextEditingController();
  final _newPassword = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerNickname = TextEditingController();
  final _registerPassword = TextEditingController();
  final _registerCode = TextEditingController();
  var _recoveryMode = false;
  var _registerMode = false;
  var _registerCodeSent = false;
  var _passwordMfaMode = false;
  var _passwordMfaCodeSent = false;
  List<String> _passwordMfaFactors = const [];
  String? _selectedPasswordMfaFactor;
  final _cooldowns = <_CooldownKind, int>{};
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _request = widget.client.createAuthorizationRequest(
      state: widget.config.state,
      nonce: widget.config.nonce,
      serverHandoff: widget.config.serverHandoffEndpoint != null,
    );
    _loadAuthorization();
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _passwordEmail.dispose();
    _password.dispose();
    _mfaCode.dispose();
    _code.dispose();
    _recoveryAccount.dispose();
    _recoveryCode.dispose();
    _newPassword.dispose();
    _registerEmail.dispose();
    _registerNickname.dispose();
    _registerPassword.dispose();
    _registerCode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthorization() async {
    try {
      widget.client.logger.info(
        'Native authorization loading started.',
        source: 'rosm_passport.ui.sign_in',
        event: 'authorization.load.start',
      );
      final start = await widget.client.startNativeAuthorization(_request);
      if (!mounted) return;
      setState(() {
        _start = start;
        _loading = false;
      });
      widget.client.logger.info(
        'Native authorization loaded.',
        source: 'rosm_passport.ui.sign_in',
        event: 'authorization.load.success',
      );
    } on Object catch (error, stackTrace) {
      widget.client.logger.error(
        'Native authorization loading failed.',
        source: 'rosm_passport.ui.sign_in',
        event: 'authorization.load.failure',
        context: _errorContext(error),
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _sendCode() async {
    await _run(() async {
      final captchaToken = await widget.config.requestCaptchaToken?.call();
      if (_mode == _SignInMode.email) {
        final result = await widget.client.sendEmailLoginCode(
          email: _email.text.trim(),
          captchaToken: captchaToken,
        );
        _startCooldown(_CooldownKind.login, result.retryAfter ?? 30);
      } else {
        final result = await widget.client.sendPhoneLoginCode(
          phoneNumber: _phone.text.trim(),
          captchaToken: captchaToken,
        );
        _startCooldown(_CooldownKind.login, result.retryAfter ?? 60);
      }
      setState(() => _sent = true);
    });
  }

  Future<void> _loginWithCode() async {
    await _run(() async {
      final auth = _mode == _SignInMode.email
          ? await widget.client.loginWithEmailCode(
              email: _email.text.trim(),
              emailCode: _code.text.trim(),
            )
          : await widget.client.loginWithPhoneCode(
              phoneNumber: _phone.text.trim(),
              verifyCode: _code.text.trim(),
            );
      _showConsent(auth);
    });
  }

  Future<void> _preparePasswordLogin() async {
    await _run(() async {
      final factors = await widget.client.passwordFactors(
        email: _passwordEmail.text.trim(),
        password: _password.text,
        captchaToken: await widget.config.requestCaptchaToken?.call(),
      );
      if (factors.directLogin) {
        final auth = await widget.client.loginWithPassword(
          email: _passwordEmail.text.trim(),
          password: _password.text,
        );
        _showConsent(auth);
        return;
      }
      setState(() {
        _passwordMfaFactors = factors.factors;
        _selectedPasswordMfaFactor = null;
        _passwordMfaCodeSent = false;
        _passwordMfaMode = true;
        _mfaCode.clear();
      });
    });
  }

  Future<void> _selectPasswordMfaFactor(String factor) async {
    setState(() {
      _selectedPasswordMfaFactor = factor;
      _passwordMfaCodeSent = false;
      _error = null;
      _mfaCode.clear();
    });
    if (factor == 'email_code' || factor == 'phone_code') {
      await _sendPasswordMfaCode();
    }
  }

  Future<void> _sendPasswordMfaCode() async {
    final factor = _selectedPasswordMfaFactor;
    if (factor != 'email_code' && factor != 'phone_code') {
      return;
    }
    final factorType = factor!;
    await _run(() async {
      final result = await widget.client.sendPasswordMfaCode(
        email: _passwordEmail.text.trim(),
        password: _password.text,
        factorType: factorType,
        captchaToken: await widget.config.requestCaptchaToken?.call(),
      );
      _startCooldown(_CooldownKind.passwordMfa, result.retryAfter ?? 45);
      setState(() => _passwordMfaCodeSent = true);
    });
  }

  Future<void> _completePasswordMfa() async {
    final factor = _selectedPasswordMfaFactor;
    if (factor == null) {
      return;
    }
    if (factor == 'webauthn') {
      await _loginWithPasskeyForPasswordMfa();
      return;
    }
    await _run(() async {
      final auth = await widget.client.loginWithPassword(
        email: _passwordEmail.text.trim(),
        password: _password.text,
        factorType: factor,
        emailCode: factor == 'email_code' ? _mfaCode.text.trim() : null,
        phoneCode: factor == 'phone_code' ? _mfaCode.text.trim() : null,
        authenticatorCode: factor == 'authenticator'
            ? _mfaCode.text.trim()
            : null,
        captchaToken: await widget.config.requestCaptchaToken?.call(),
      );
      _showConsent(auth);
    });
  }

  Future<void> _loginWithPasskeyForPasswordMfa() async {
    final authenticator =
        widget.config.authenticatePasskey ??
        (options) => RosmNativePasskeys(
          logger: widget.client.logger,
        ).authenticate(options);
    await _run(() async {
      final email = _passwordEmail.text.trim();
      widget.client.logger.info(
        'Password MFA passkey options request started.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.mfa.options.start',
        context: {'has_email': email.isNotEmpty},
      );
      final options = await widget.client.beginWebAuthnLogin(email: email);
      widget.client.logger.info(
        'Password MFA passkey options received.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.mfa.options.success',
      );
      final credential = await authenticator(options);
      widget.client.logger.info(
        'Password MFA passkey credential received; verifying with server.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.mfa.verify.start',
        context: _credentialSummary(credential),
      );
      final auth = await widget.client.completeWebAuthnLogin(
        email: email,
        credential: credential,
      );
      widget.client.logger.info(
        'Password MFA passkey verification completed.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.mfa.verify.success',
      );
      _showConsent(auth);
    });
  }

  Future<void> _loginWithPasskey() async {
    final authenticator =
        widget.config.authenticatePasskey ??
        (options) => RosmNativePasskeys(
          logger: widget.client.logger,
        ).authenticate(options);
    await _run(() async {
      final email = _email.text.trim().isEmpty ? null : _email.text.trim();
      widget.client.logger.info(
        'Passkey login options request started.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.login.options.start',
        context: {'has_email': email != null},
      );
      final options = await widget.client.beginWebAuthnLogin(email: email);
      widget.client.logger.info(
        'Passkey login options received.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.login.options.success',
      );
      final credential = await authenticator(options);
      widget.client.logger.info(
        'Passkey login credential received; verifying with server.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.login.verify.start',
        context: _credentialSummary(credential),
      );
      final auth = await widget.client.completeWebAuthnLogin(
        email: email,
        credential: credential,
      );
      widget.client.logger.info(
        'Passkey login verification completed.',
        source: 'rosm_passport.ui.sign_in',
        event: 'passkey.login.verify.success',
      );
      _showConsent(auth);
    });
  }

  Future<void> _sendRecoveryCode() async {
    await _run(() async {
      final account = _recoveryAccount.text.trim();
      final captchaToken = await widget.config.requestCaptchaToken?.call();
      if (captchaToken == null || captchaToken.isEmpty) {
        throw const RosmApiException('captcha_required', '请先完成人机验证。');
      }
      final result = await widget.client.sendPasswordRecoveryCode(
        account: account,
        method: account.contains('@')
            ? RosmPasswordRecoveryMethod.email
            : RosmPasswordRecoveryMethod.phone,
        captchaToken: captchaToken,
      );
      _startCooldown(_CooldownKind.recovery, result.retryAfter ?? 45);
      setState(() => _sent = true);
    });
  }

  Future<void> _resetPassword() async {
    await _run(() async {
      final account = _recoveryAccount.text.trim();
      await widget.client.resetPasswordByCode(
        account: account,
        method: account.contains('@')
            ? RosmPasswordRecoveryMethod.email
            : RosmPasswordRecoveryMethod.phone,
        code: _recoveryCode.text.trim(),
        newPassword: _newPassword.text,
      );
      setState(() {
        _recoveryMode = false;
        _mode = _SignInMode.password;
        _sent = false;
        _error = '密码已重置，请使用新密码登录。';
      });
    });
  }

  Future<void> _sendRegisterCode() async {
    await _run(() async {
      final captchaToken = await widget.config.requestCaptchaToken?.call();
      if (captchaToken == null || captchaToken.isEmpty) {
        throw const RosmApiException('captcha_required', '请先完成人机验证。');
      }
      final result = await widget.client.sendRegisterCode(
        email: _registerEmail.text.trim(),
        captchaToken: captchaToken,
      );
      _startCooldown(_CooldownKind.register, result.retryAfter ?? 45);
      setState(() => _registerCodeSent = true);
    });
  }

  Future<void> _registerWithEmail() async {
    await _run(() async {
      final auth = await widget.client.registerWithEmail(
        email: _registerEmail.text.trim(),
        nickname: _registerNickname.text.trim(),
        password: _registerPassword.text,
        emailCode: _registerCode.text.trim(),
      );
      _showConsent(auth);
    });
  }

  void _showConsent(RosmAuthResult auth) {
    if (!mounted) return;
    widget.client.logger.info(
      'Login completed; showing consent.',
      source: 'rosm_passport.ui.sign_in',
      event: 'login.success',
      context: {'user_id': auth.user.id},
    );
    setState(() {
      _pendingAuth = auth;
      _error = null;
      _sent = false;
      _recoveryMode = false;
      _registerMode = false;
      _passwordMfaMode = false;
    });
  }

  Future<void> _approveAndFinish() async {
    final auth = _pendingAuth;
    if (auth == null) {
      return;
    }
    await _run(() async {
      await _finish(auth);
    });
  }

  Future<void> _denyAuthorization() async {
    await _run(() async {
      await widget.client.cancelNativeAuthorization(_request);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _finish(RosmAuthResult auth) async {
    widget.client.logger.info(
      'Authorization approval started.',
      source: 'rosm_passport.ui.sign_in',
      event: 'authorization.approve.start',
    );
    final approval = await widget.client.approveNativeAuthorization(_request);
    final endpoint = widget.config.serverHandoffEndpoint;
    if (endpoint == null) {
      final tokens = await widget.client.exchangeCode(
        request: _request,
        approval: approval,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        RosmPassportUiResult(
          auth: auth,
          authorization: approval,
          tokens: tokens,
        ),
      );
      widget.client.logger.info(
        'Authorization finished with direct token exchange.',
        source: 'rosm_passport.ui.sign_in',
        event: 'authorization.approve.success',
      );
      return;
    }
    final handoff = await widget.client.completeServerHandoff(
      endpoint: endpoint,
      request: _request,
      approval: approval,
      headers: widget.config.serverHandoffHeaders,
      extra: widget.config.serverHandoffExtra,
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      RosmPassportUiResult(
        auth: auth,
        authorization: approval,
        serverPayload: handoff.payload,
      ),
    );
    widget.client.logger.info(
      'Authorization finished with server handoff.',
      source: 'rosm_passport.ui.sign_in',
      event: 'authorization.approve.success',
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error, stackTrace) {
      widget.client.logger.warning(
        'Sign-in action failed.',
        source: 'rosm_passport.ui.sign_in',
        event: 'ui.action.failure',
        context: _errorContext(error),
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Map<String, Object?> _errorContext(Object error) {
    if (error is RosmApiException) {
      return {
        'error_code': error.code,
        if (error.statusCode != null) 'status_code': error.statusCode,
      };
    }
    return {'error_type': error.runtimeType.toString()};
  }

  Map<String, Object?> _credentialSummary(RosmWebAuthnCredential credential) {
    final response = credential.response['response'];
    final responseMap = response is Map ? response : const {};
    return {
      'credential_id_length': credential.response['id']?.toString().length ?? 0,
      'raw_id_length': credential.response['rawId']?.toString().length ?? 0,
      'type': credential.response['type']?.toString(),
      'has_client_data_json': responseMap.containsKey('clientDataJSON'),
      'has_authenticator_data': responseMap.containsKey('authenticatorData'),
      'has_signature': responseMap.containsKey('signature'),
      'has_attestation_object': responseMap.containsKey('attestationObject'),
    };
  }

  int _cooldownFor(_CooldownKind kind) => _cooldowns[kind] ?? 0;

  bool _coolingDown(_CooldownKind kind) => _cooldownFor(kind) > 0;

  String _codeButtonLabel(_CooldownKind kind, String readyLabel) {
    final remaining = _cooldownFor(kind);
    return remaining > 0 ? '${remaining}秒' : readyLabel;
  }

  void _startCooldown(_CooldownKind kind, int seconds) {
    if (seconds <= 0) {
      return;
    }
    setState(() => _cooldowns[kind] = seconds);
    _cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
        return;
      }
      setState(() {
        final finished = <_CooldownKind>[];
        for (final entry in _cooldowns.entries) {
          final next = entry.value - 1;
          if (next <= 0) {
            finished.add(entry.key);
          } else {
            _cooldowns[entry.key] = next;
          }
        }
        for (final kind in finished) {
          _cooldowns.remove(kind);
        }
        if (_cooldowns.isEmpty) {
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = _activeMode;
    return Theme(
      data: theme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5F7F63),
          primary: _RosmColors.sage600,
          surface: _RosmColors.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _RosmColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          labelStyle: const TextStyle(
            color: _RosmColors.sage700,
            fontWeight: FontWeight.w700,
          ),
          prefixIconColor: _RosmColors.sage500,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _RosmColors.sage200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _RosmColors.sage500,
              width: 1.4,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _RosmColors.sage600,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            elevation: 3,
            shadowColor: const Color(0x33577557),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _RosmColors.sage700,
            side: const BorderSide(color: _RosmColors.sage300),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _RosmColors.surface,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _RosmColors.sage600),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: '关闭',
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded),
                            color: _RosmColors.sage500,
                          ),
                        ),
                        _Header(
                          start: _start,
                          mode: mode,
                          confirmingConsent: _pendingAuth != null,
                        ),
                        const SizedBox(height: 26),
                        if (_error != null) ...[
                          _Message(text: _error!),
                          const SizedBox(height: 18),
                        ],
                        if (_pendingAuth != null)
                          _ConsentPage(
                            appName: _start?.client.displayName,
                            scopes: _start?.scopes ?? const [],
                            busy: _busy,
                            onApprove: _approveAndFinish,
                            onDeny: _denyAuthorization,
                          )
                        else if (_recoveryMode)
                          _Card(child: _buildRecovery())
                        else if (_passwordMfaMode)
                          _Card(child: _buildPasswordMfa())
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_registerMode)
                                _buildRegister()
                              else ...[
                                _buildModeTabs(),
                                const SizedBox(height: 36),
                                _buildModeBody(),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    final modes = _availableModes;
    if (modes.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!modes.contains(_mode) && modes.isNotEmpty) {
      _mode = modes.first;
    }
    return SegmentedButton<_SignInMode>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : _RosmColors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? _RosmColors.ink
              : _RosmColors.sage500;
        }),
        side: const WidgetStatePropertyAll(
          BorderSide(color: _RosmColors.sage200, width: 1.2),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      segments: modes
          .map(
            (mode) => ButtonSegment<_SignInMode>(
              value: mode,
              label: Text(_labelFor(mode)),
            ),
          )
          .toList(),
      selected: {_mode},
      onSelectionChanged: _busy
          ? null
          : (selected) {
              setState(() {
                _mode = selected.first;
                _sent = false;
                _passwordMfaMode = false;
                _error = null;
              });
            },
    );
  }

  List<_SignInMode> get _availableModes {
    return [
      if (widget.config.enablePhoneCode) _SignInMode.phone,
      if (widget.config.enableEmailCode) _SignInMode.email,
      if (widget.config.enablePasskey) _SignInMode.passkey,
      if (widget.config.enablePassword) _SignInMode.password,
    ];
  }

  _SignInMode get _activeMode {
    final modes = _availableModes;
    if (modes.isEmpty || modes.contains(_mode)) {
      return _mode;
    }
    _mode = modes.first;
    return _mode;
  }

  Widget _buildModeBody() {
    if (_mode == _SignInMode.password) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _passwordEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _preparePasswordLogin,
            child: _ButtonContent(busy: _busy, label: '继续登录  →', light: true),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _recoveryMode = true),
            child: const Text('忘记密码'),
          ),
          if (widget.config.enableRegistration)
            _RegisterPrompt(onTap: _openRegister),
        ],
      );
    }

    if (_mode == _SignInMode.passkey) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱（可选）',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _loginWithPasskey,
            child: _ButtonContent(
              busy: _busy,
              label: '使用通行密钥登录  →',
              light: true,
            ),
          ),
          if (widget.config.enableRegistration)
            _RegisterPrompt(onTap: _openRegister),
        ],
      );
    }

    final isEmail = _mode == _SignInMode.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: isEmail ? _email : _phone,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.phone,
          decoration: InputDecoration(
            labelText: isEmail ? '邮箱' : '手机号',
            prefixIcon: Icon(
              isEmail ? Icons.mail_outline_rounded : Icons.phone_iphone_rounded,
            ),
          ),
        ),
        if (_sent) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: OutlinedButton(
                  onPressed: _busy || _coolingDown(_CooldownKind.login)
                      ? null
                      : _sendCode,
                  child: _ButtonContent(
                    busy: _busy,
                    label: _codeButtonLabel(_CooldownKind.login, '重发'),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : (_sent ? _loginWithCode : _sendCode),
          child: _ButtonContent(
            busy: _busy,
            label: _sent
                ? '登录并授权  →'
                : isEmail
                ? '发送邮箱验证码  →'
                : '发送登录验证码  →',
            light: true,
          ),
        ),
        if (widget.config.enableRegistration)
          _RegisterPrompt(onTap: _openRegister),
      ],
    );
  }

  Widget _buildPasswordMfa() {
    final factor = _selectedPasswordMfaFactor;
    final title = factor == null ? '选择验证方式' : _passwordMfaTitle(factor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _RosmColors.ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          factor == null ? '为了保护账号安全，请选择一种二次验证方式。' : _passwordMfaIntro(factor),
          style: const TextStyle(
            color: _RosmColors.sage500,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        if (factor == null)
          for (final item in _passwordMfaFactors)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FactorButton(
                icon: _passwordMfaIcon(item),
                title: _passwordMfaTitle(item),
                subtitle: _passwordMfaIntro(item),
                onTap: _busy ? null : () => _selectPasswordMfaFactor(item),
              ),
            )
        else ...[
          if (factor == 'email_code' || factor == 'phone_code') ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mfaCode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: factor == 'email_code' ? '邮箱验证码' : '手机验证码',
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 106,
                  child: OutlinedButton(
                    onPressed: _busy || _coolingDown(_CooldownKind.passwordMfa)
                        ? null
                        : _sendPasswordMfaCode,
                    child: _ButtonContent(
                      busy: _busy,
                      label: _codeButtonLabel(
                        _CooldownKind.passwordMfa,
                        _passwordMfaCodeSent ? '重发' : '发送',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (factor == 'authenticator') ...[
            TextField(
              controller: _mfaCode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '动态验证码',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _completePasswordMfa,
            child: _ButtonContent(
              busy: _busy,
              label: factor == 'webauthn' ? '使用通行密钥验证  →' : '完成登录  →',
              light: true,
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _selectedPasswordMfaFactor = null;
                    _passwordMfaCodeSent = false;
                    _mfaCode.clear();
                    _error = null;
                  }),
            child: const Text('更换验证方式'),
          ),
        ],
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _passwordMfaMode = false;
                  _selectedPasswordMfaFactor = null;
                  _passwordMfaCodeSent = false;
                  _mfaCode.clear();
                  _error = null;
                }),
          child: const Text('返回密码登录'),
        ),
      ],
    );
  }

  void _openRegister() {
    setState(() {
      _registerMode = true;
      _recoveryMode = false;
      _passwordMfaMode = false;
      _error = null;
      _sent = false;
    });
  }

  Widget _buildRegister() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '创建 ROSM 账号',
            style: TextStyle(
              color: _RosmColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '使用邮箱验证码完成注册，随后继续确认授权。',
            style: TextStyle(
              color: _RosmColors.sage500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _registerEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _registerCode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 106,
                child: OutlinedButton(
                  onPressed: _busy || _coolingDown(_CooldownKind.register)
                      ? null
                      : _sendRegisterCode,
                  child: _ButtonContent(
                    busy: _busy,
                    label: _codeButtonLabel(
                      _CooldownKind.register,
                      _registerCodeSent ? '重发' : '发送',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _registerNickname,
            decoration: const InputDecoration(
              labelText: '昵称',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _registerPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _registerWithEmail,
            child: _ButtonContent(busy: _busy, label: '注册并继续  →', light: true),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _registerMode = false;
                    _registerCodeSent = false;
                    _error = null;
                  }),
            child: const Text('已有账号，返回登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecovery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '重置密码',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _recoveryAccount,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '邮箱或手机号'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _recoveryCode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '验证码'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _busy || _coolingDown(_CooldownKind.recovery)
                  ? null
                  : _sendRecoveryCode,
              child: _ButtonContent(
                busy: _busy,
                label: _codeButtonLabel(
                  _CooldownKind.recovery,
                  _sent ? '重发' : '发送',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _resetPassword,
          child: _ButtonContent(busy: _busy, label: '重置密码', light: true),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _recoveryMode = false),
          child: const Text('返回登录'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.start,
    required this.mode,
    required this.confirmingConsent,
  });

  final RosmAuthorizationStart? start;
  final _SignInMode mode;
  final bool confirmingConsent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ROSM 通行证',
          style: TextStyle(
            color: _RosmColors.sage600,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            _RosmPassportSignInPageState._logoUri.toString(),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _RosmColors.sage100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: _RosmColors.sage600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          confirmingConsent ? '确认授权' : '欢迎回来',
          style: const TextStyle(
            color: _RosmColors.ink,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          confirmingConsent
              ? _consentIntroFor(start?.client.displayName)
              : _introFor(mode, start?.client.displayName),
          style: const TextStyle(
            color: _RosmColors.sage500,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ConsentPage extends StatelessWidget {
  const _ConsentPage({
    required this.scopes,
    required this.busy,
    required this.onApprove,
    required this.onDeny,
    this.appName,
  });

  final List<RosmScopeInfo> scopes;
  final String? appName;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final normalizedName = appName?.trim();
    final title = normalizedName == null || normalizedName.isEmpty
        ? '确认授权'
        : '授权给 $normalizedName';
    final meanings = _scopeMeanings(scopes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _RosmColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '继续后，该应用将获得以下授权能力。',
                style: TextStyle(
                  color: _RosmColors.sage500,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              for (final meaning in meanings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _RosmColors.sage600,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          meaning,
                          style: const TextStyle(
                            color: _RosmColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onApprove,
          child: _ButtonContent(busy: busy, label: '确认授权并继续  →', light: true),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: busy ? null : onDeny,
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDBFFFFFF),
        border: Border.all(color: _RosmColors.sage100),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F161D16),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B8B0)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFFB42318))),
    );
  }
}

class _FactorButton extends StatelessWidget {
  const _FactorButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _RosmColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _RosmColors.sage500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 22),
        ],
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.busy,
    required this.label,
    this.light = false,
  });

  final bool busy;
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    if (!busy) {
      return Text(label);
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(
          light ? Colors.white : _RosmColors.sage600,
        ),
      ),
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '还没有账号？',
            style: TextStyle(
              color: _RosmColors.sage500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('立即注册')),
        ],
      ),
    );
  }
}

enum _SignInMode { phone, email, passkey, password }

enum _CooldownKind { login, passwordMfa, register, recovery }

String _labelFor(_SignInMode mode) {
  return switch (mode) {
    _SignInMode.phone => '手机',
    _SignInMode.email => '验证码',
    _SignInMode.passkey => '通行密钥',
    _SignInMode.password => '密码',
  };
}

String _passwordMfaTitle(String factor) {
  return switch (factor) {
    'email_code' => '邮箱验证码',
    'phone_code' => '手机验证码',
    'authenticator' => 'Authenticator 验证器',
    'webauthn' => '系统通行密钥',
    _ => '二次验证',
  };
}

String _passwordMfaIntro(String factor) {
  return switch (factor) {
    'email_code' => '发送一次登录验证码到当前账户邮箱。',
    'phone_code' => '发送一次登录验证码到当前账户已绑定手机号。',
    'authenticator' => '输入动态口令应用中当前显示的 6 位验证码。',
    'webauthn' => '使用系统通行密钥完成本次安全验证。',
    _ => '完成账号安全验证后继续登录。',
  };
}

IconData _passwordMfaIcon(String factor) {
  return switch (factor) {
    'email_code' => Icons.mail_outline_rounded,
    'phone_code' => Icons.phone_iphone_rounded,
    'authenticator' => Icons.shield_outlined,
    'webauthn' => Icons.fingerprint_rounded,
    _ => Icons.verified_user_outlined,
  };
}

String _introFor(_SignInMode mode, String? appName) {
  final suffix = appName == null || appName.trim().isEmpty
      ? '完成登录。'
      : '完成登录并授权 ${appName.trim()}。';
  return switch (mode) {
    _SignInMode.phone => '请输入手机号并使用短信验证码$suffix',
    _SignInMode.email => '请输入邮箱并使用验证码$suffix',
    _SignInMode.passkey => '使用系统通行密钥安全$suffix',
    _SignInMode.password => '请输入邮箱和密码$suffix',
  };
}

String _consentIntroFor(String? appName) {
  final normalizedName = appName?.trim();
  if (normalizedName == null || normalizedName.isEmpty) {
    return '请确认是否允许该应用使用你的 ROSM 账号登录。';
  }
  return '请确认是否允许 $normalizedName 使用你的 ROSM 账号登录。';
}

String _messageFor(Object error) {
  if (error is RosmApiException) {
    return error.message;
  }
  return error.toString();
}

List<String> _scopeMeanings(List<RosmScopeInfo> scopes) {
  final meanings = <String>[];
  for (final scope in scopes) {
    final meaning = switch (scope.name) {
      'openid' => '确认你的 ROSM 登录身份',
      'profile' => '读取你的基础资料，例如昵称',
      'email' => '读取你的邮箱地址和验证状态',
      'phone' => '读取你的手机号和验证状态',
      'accountRule' => '读取你的账号角色，用于判断权限',
      'offline_access' => '在你离开应用后保持登录状态',
      _ => scope.description.trim().isEmpty ? '使用已授权服务' : scope.description,
    };
    if (!meanings.contains(meaning)) {
      meanings.add(meaning);
    }
  }
  return meanings.isEmpty ? const ['确认你的 ROSM 登录身份'] : meanings;
}

class _RosmColors {
  const _RosmColors._();

  static const surface = Color(0xFFFAFCFA);
  static const ink = Color(0xFF161D16);
  static const sage100 = Color(0xFFE2E9E2);
  static const sage200 = Color(0xFFC5D3C5);
  static const sage300 = Color(0xFFA8BDA8);
  static const sage500 = Color(0xFF6E926E);
  static const sage600 = Color(0xFF577557);
  static const sage700 = Color(0xFF415841);
}
