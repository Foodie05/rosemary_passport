import 'package:flutter/material.dart';

import 'models.dart';
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
  final _code = TextEditingController();
  final _recoveryAccount = TextEditingController();
  final _recoveryCode = TextEditingController();
  final _newPassword = TextEditingController();
  var _recoveryMode = false;

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
    _code.dispose();
    _recoveryAccount.dispose();
    _recoveryCode.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _loadAuthorization() async {
    try {
      final start = await widget.client.startNativeAuthorization(_request);
      if (!mounted) return;
      setState(() {
        _start = start;
        _loading = false;
      });
    } on Object catch (error) {
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
        await widget.client.sendEmailLoginCode(
          email: _email.text.trim(),
          captchaToken: captchaToken,
        );
      } else {
        await widget.client.sendPhoneLoginCode(
          phoneNumber: _phone.text.trim(),
          captchaToken: captchaToken,
        );
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

  Future<void> _loginWithPassword() async {
    await _run(() async {
      final auth = await widget.client.loginWithPassword(
        email: _passwordEmail.text.trim(),
        password: _password.text,
        captchaToken: await widget.config.requestCaptchaToken?.call(),
      );
      _showConsent(auth);
    });
  }

  Future<void> _loginWithPasskey() async {
    final authenticator = widget.config.authenticatePasskey;
    if (authenticator == null) {
      setState(() => _error = '当前应用尚未接入系统通行密钥能力。');
      return;
    }
    await _run(() async {
      final email = _email.text.trim().isEmpty ? null : _email.text.trim();
      final options = await widget.client.beginWebAuthnLogin(email: email);
      final credential = await authenticator(options);
      final auth = await widget.client.completeWebAuthnLogin(
        email: email,
        credential: credential,
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
      await widget.client.sendPasswordRecoveryCode(
        account: account,
        method: account.contains('@')
            ? RosmPasswordRecoveryMethod.email
            : RosmPasswordRecoveryMethod.phone,
        captchaToken: captchaToken,
      );
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

  void _showConsent(RosmAuthResult auth) {
    if (!mounted) return;
    setState(() {
      _pendingAuth = auth;
      _error = null;
      _sent = false;
      _recoveryMode = false;
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
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
              fontWeight: FontWeight.w800,
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
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildModeTabs(),
                              const SizedBox(height: 36),
                              _buildModeBody(),
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
          TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
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
            onPressed: _busy ? null : _loginWithPassword,
            child: Text(_busy ? '处理中...' : '登录并授权  →'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _recoveryMode = true),
            child: const Text('忘记密码'),
          ),
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
            child: Text(_busy ? '处理中...' : '使用通行密钥登录  →'),
          ),
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
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('重发'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : (_sent ? _loginWithCode : _sendCode),
          child: Text(
            _busy
                ? '处理中...'
                : _sent
                ? '登录并授权  →'
                : isEmail
                ? '发送邮箱验证码  →'
                : '发送登录验证码  →',
          ),
        ),
      ],
    );
  }

  Widget _buildRecovery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '重置密码',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
              onPressed: _busy ? null : _sendRecoveryCode,
              child: Text(_sent ? '重发' : '发送'),
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
          child: Text(_busy ? '处理中...' : '重置密码'),
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
            fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '继续后，该应用将获得以下授权能力。',
                style: TextStyle(
                  color: _RosmColors.sage500,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.w700,
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
          child: Text(busy ? '处理中...' : '确认授权并继续  →'),
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

enum _SignInMode { phone, email, passkey, password }

String _labelFor(_SignInMode mode) {
  return switch (mode) {
    _SignInMode.phone => '手机',
    _SignInMode.email => '验证码',
    _SignInMode.passkey => '通行密钥',
    _SignInMode.password => '密码',
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
