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
  late final RosmAuthorizationRequest _request;
  RosmAuthorizationStart? _start;
  var _mode = _SignInMode.email;
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
      await _finish(auth);
    });
  }

  Future<void> _loginWithPassword() async {
    await _run(() async {
      final auth = await widget.client.loginWithPassword(
        email: _passwordEmail.text.trim(),
        password: _password.text,
        captchaToken: await widget.config.requestCaptchaToken?.call(),
      );
      await _finish(auth);
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
      await _finish(auth);
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
    return Theme(
      data: theme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5F7F63),
          primary: const Color(0xFF2C6F8F),
          surface: const Color(0xFFF5F8F3),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8F3),
        appBar: AppBar(
          title: Text(_start?.client.displayName ?? 'ROSM 通行证'),
          backgroundColor: const Color(0xFFF5F8F3),
          foregroundColor: const Color(0xFF1F2A2D),
          elevation: 0,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _Header(start: _start),
                    const SizedBox(height: 18),
                    if (_error != null) _Message(text: _error!),
                    const SizedBox(height: 12),
                    _Card(
                      child: _recoveryMode
                          ? _buildRecovery()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildModeTabs(),
                                const SizedBox(height: 18),
                                _buildModeBody(),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),
                    _ScopeList(scopes: _start?.scopes ?? const []),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    final modes = <_SignInMode>[
      if (widget.config.enableEmailCode) _SignInMode.email,
      if (widget.config.enablePhoneCode) _SignInMode.phone,
      if (widget.config.enablePassword) _SignInMode.password,
    ];
    if (!modes.contains(_mode) && modes.isNotEmpty) {
      _mode = modes.first;
    }
    return SegmentedButton<_SignInMode>(
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

  Widget _buildModeBody() {
    if (_mode == _SignInMode.password) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _passwordEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '邮箱'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _loginWithPassword,
            child: Text(_busy ? '处理中...' : '登录并授权'),
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

    final isEmail = _mode == _SignInMode.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: isEmail ? _email : _phone,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.phone,
          decoration: InputDecoration(labelText: isEmail ? '邮箱' : '手机号'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '验证码'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(_sent ? '重发' : '发送'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _loginWithCode,
          child: Text(_busy ? '处理中...' : '登录并授权'),
        ),
        if (widget.config.enablePasskey) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _loginWithPasskey,
            child: const Text('使用通行密钥'),
          ),
        ],
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
  const _Header({required this.start});

  final RosmAuthorizationStart? start;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFD4E8F7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user,
            color: Color(0xFF0F5474),
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          start == null ? 'ROSM 通行证' : '${start!.client.displayName} 通行证',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF172027),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '登录后可同步账号状态并使用已授权服务',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF536067), fontSize: 15),
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
        border: Border.all(color: const Color(0xFFC8D8C7)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5F7F63),
            blurRadius: 24,
            offset: Offset(0, 12),
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

class _ScopeList extends StatelessWidget {
  const _ScopeList({required this.scopes});

  final List<RosmScopeInfo> scopes;

  @override
  Widget build(BuildContext context) {
    if (scopes.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '授权范围',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          for (final scope in scopes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Color(0xFF2C6F8F),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${scope.name}: ${scope.description}',
                      style: const TextStyle(color: Color(0xFF536067)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _SignInMode { email, phone, password }

String _labelFor(_SignInMode mode) {
  return switch (mode) {
    _SignInMode.email => '邮箱',
    _SignInMode.phone => '手机',
    _SignInMode.password => '密码',
  };
}

String _messageFor(Object error) {
  if (error is RosmApiException) {
    return error.message;
  }
  return error.toString();
}
