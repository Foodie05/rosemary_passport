import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'rosm_native_passkeys.dart';
import 'rosm_passport_client.dart';

class RosmPassportAccountConfig {
  const RosmPassportAccountConfig({
    this.requestCaptchaToken,
    this.registerPasskey,
  });

  final Future<String?> Function()? requestCaptchaToken;
  final Future<RosmWebAuthnCredential> Function(RosmWebAuthnOptions options)?
  registerPasskey;
}

Future<void> showRosmPassportAccountManagement(
  BuildContext context, {
  required RosmPassportClient client,
  RosmPassportAccountConfig config = const RosmPassportAccountConfig(),
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RosmPassportAccountPage(client: client, config: config),
    ),
  );
}

class RosmPassportAccountPage extends StatefulWidget {
  const RosmPassportAccountPage({
    required this.client,
    this.config = const RosmPassportAccountConfig(),
    super.key,
  });

  final RosmPassportClient client;
  final RosmPassportAccountConfig config;

  @override
  State<RosmPassportAccountPage> createState() =>
      _RosmPassportAccountPageState();
}

class _RosmPassportAccountPageState extends State<RosmPassportAccountPage> {
  RosmAccountState? _account;
  RosmPasskeyList? _passkeys;
  var _loading = true;
  var _busy = false;
  String? _error;

  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _code = TextEditingController();
  final _authenticatorCode = TextEditingController();
  RosmAuthenticatorSetup? _authenticatorSetup;

  final _cooldowns = <_AccountCooldown, int>{};
  final _cooldownRefreshers = <_AccountCooldown, VoidCallback>{};
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _code.dispose();
    _authenticatorCode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await widget.client.account();
      RosmPasskeyList? passkeys;
      try {
        passkeys = await widget.client.listPasskeys();
      } on Object {
        passkeys = null;
      }
      if (!mounted) return;
      setState(() {
        _account = account;
        _passkeys = passkeys;
        _nickname.text = account.user.nickname;
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

  Future<void> _runInSheet(
    StateSetter setSheetState,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _refreshSheet(setSheetState);
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refreshSheet(setSheetState);
      }
    }
  }

  void _refreshSheet(StateSetter setSheetState) {
    try {
      setSheetState(() {});
    } on FlutterError {
      // The sheet may have just been closed by a successful submit action.
    }
  }

  void _bindSheetCooldown(_AccountCooldown kind, StateSetter setSheetState) {
    _cooldownRefreshers[kind] = () => _refreshSheet(setSheetState);
  }

  Future<String> _captchaToken() async {
    final token = await widget.config.requestCaptchaToken?.call();
    if (token == null || token.trim().isEmpty) {
      throw const RosmApiException('captcha_required', '请先完成人机验证。');
    }
    return token;
  }

  Future<void> _saveNickname() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) return;
    await _run(() async {
      await widget.client.updateAccount(nickname: nickname);
      await _load();
    });
  }

  Future<void> _openEmailDialog() async {
    _email.text = _account?.user.email ?? '';
    _currentPassword.clear();
    _code.clear();
    try {
      await _showSheet(
        title: '绑定邮箱',
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            _bindSheetCooldown(_AccountCooldown.email, setSheetState);
            return _SheetBody(
              error: _error,
              child: _EmailSheet(
                email: _email,
                currentPassword: _currentPassword,
                code: _code,
                busy: _busy,
                cooldownLabel: _cooldownLabel(_AccountCooldown.email, '发送'),
                sendDisabled: _coolingDown(_AccountCooldown.email),
                onSend: () => _runInSheet(setSheetState, () async {
                  final result = await widget.client.sendBindEmailCode(
                    email: _email.text.trim(),
                    currentPassword: _currentPassword.text,
                    captchaToken: await _captchaToken(),
                  );
                  _startCooldown(
                    _AccountCooldown.email,
                    result.retryAfter ?? 45,
                  );
                }),
                onSubmit: () => _runInSheet(setSheetState, () async {
                  await widget.client.bindEmail(
                    email: _email.text.trim(),
                    currentPassword: _currentPassword.text,
                    emailCode: _code.text.trim(),
                  );
                  if (mounted) Navigator.of(context).pop();
                  await _load();
                }),
              ),
            );
          },
        ),
      );
    } finally {
      _cooldownRefreshers.remove(_AccountCooldown.email);
    }
  }

  Future<void> _openPhoneDialog() async {
    _phone.text = _account?.user.phoneNumber ?? '';
    _currentPassword.clear();
    _code.clear();
    try {
      await _showSheet(
        title: '绑定手机号',
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            _bindSheetCooldown(_AccountCooldown.phone, setSheetState);
            return _SheetBody(
              error: _error,
              child: _PhoneSheet(
                phone: _phone,
                currentPassword: _currentPassword,
                code: _code,
                busy: _busy,
                cooldownLabel: _cooldownLabel(_AccountCooldown.phone, '发送'),
                sendDisabled: _coolingDown(_AccountCooldown.phone),
                onSend: () => _runInSheet(setSheetState, () async {
                  final result = await widget.client.sendBindPhoneCode(
                    phoneNumber: _phone.text.trim(),
                    currentPassword: _currentPassword.text,
                    captchaToken: await _captchaToken(),
                  );
                  _startCooldown(
                    _AccountCooldown.phone,
                    result.retryAfter ?? 60,
                  );
                }),
                onSubmit: () => _runInSheet(setSheetState, () async {
                  await widget.client.bindPhone(
                    phoneNumber: _phone.text.trim(),
                    currentPassword: _currentPassword.text,
                    verifyCode: _code.text.trim(),
                  );
                  if (mounted) Navigator.of(context).pop();
                  await _load();
                }),
              ),
            );
          },
        ),
      );
    } finally {
      _cooldownRefreshers.remove(_AccountCooldown.phone);
    }
  }

  Future<void> _openPasswordDialog() async {
    _newPassword.clear();
    _code.clear();
    try {
      await _showSheet(
        title: '重置密码',
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            _bindSheetCooldown(_AccountCooldown.password, setSheetState);
            return _SheetBody(
              error: _error,
              child: _PasswordSheet(
                newPassword: _newPassword,
                code: _code,
                email: _account?.user.email ?? '-',
                busy: _busy,
                cooldownLabel: _cooldownLabel(_AccountCooldown.password, '发送'),
                sendDisabled: _coolingDown(_AccountCooldown.password),
                onSend: () => _runInSheet(setSheetState, () async {
                  final result = await widget.client.sendOwnPasswordResetCode(
                    captchaToken: await _captchaToken(),
                  );
                  _startCooldown(
                    _AccountCooldown.password,
                    result.retryAfter ?? 45,
                  );
                }),
                onSubmit: () => _runInSheet(setSheetState, () async {
                  await widget.client.resetOwnPassword(
                    newPassword: _newPassword.text,
                    emailCode: _code.text.trim(),
                  );
                  if (mounted) Navigator.of(context).pop();
                }),
              ),
            );
          },
        ),
      );
    } finally {
      _cooldownRefreshers.remove(_AccountCooldown.password);
    }
  }

  Future<void> _openAuthenticatorDialog() async {
    _currentPassword.clear();
    _authenticatorCode.clear();
    _authenticatorSetup = null;
    await _showSheet(
      title: _account?.security.hasAuthenticator == true ? '更新验证器' : '设置验证器',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return _AuthenticatorSheet(
            currentPassword: _currentPassword,
            code: _authenticatorCode,
            setup: _authenticatorSetup,
            busy: _busy,
            onBegin: () => _run(() async {
              final setup = await widget.client.beginAuthenticatorSetup(
                currentPassword: _currentPassword.text,
              );
              setSheetState(() => _authenticatorSetup = setup);
            }),
            onSubmit: () => _run(() async {
              final setup = _authenticatorSetup;
              if (setup == null) return;
              await widget.client.verifyAuthenticatorSetup(
                currentPassword: _currentPassword.text,
                secret: setup.secret,
                code: _authenticatorCode.text.trim(),
              );
              if (mounted) Navigator.of(context).pop();
              await _load();
            }),
          );
        },
      ),
    );
  }

  Future<void> _openPasskeyDialog() async {
    _currentPassword.clear();
    await _showSheet(
      title: '系统通行密钥',
      child: _PasskeySheet(
        passkeys: _passkeys,
        currentPassword: _currentPassword,
        busy: _busy,
        canRegister: true,
        onRefresh: () => _run(() async {
          final passkeys = await widget.client.listPasskeys();
          setState(() => _passkeys = passkeys);
        }),
        onRegister: () => _run(() async {
          final registrar =
              widget.config.registerPasskey ?? registerRosmPasskey;
          final options = await widget.client.beginPasskeyRegistration(
            currentPassword: _currentPassword.text,
          );
          final credential = await registrar(options);
          await widget.client.completePasskeyRegistration(
            credential: credential,
          );
          final passkeys = await widget.client.listPasskeys();
          setState(() => _passkeys = passkeys);
          _currentPassword.clear();
          await _load();
        }),
        onDelete: (credentialId) => _run(() async {
          await widget.client.deletePasskey(credentialId);
          final passkeys = await widget.client.listPasskeys();
          setState(() => _passkeys = passkeys);
          await _load();
        }),
      ),
    );
  }

  Future<void> _showSheet({required String title, required Widget child}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _AccountColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _AccountColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  int _cooldownFor(_AccountCooldown kind) => _cooldowns[kind] ?? 0;

  bool _coolingDown(_AccountCooldown kind) => _cooldownFor(kind) > 0;

  String _cooldownLabel(_AccountCooldown kind, String label) {
    final remaining = _cooldownFor(kind);
    return remaining > 0 ? '${remaining}秒' : label;
  }

  void _startCooldown(
    _AccountCooldown kind,
    int seconds, {
    VoidCallback? onTick,
  }) {
    if (seconds <= 0) return;
    if (onTick != null) {
      _cooldownRefreshers[kind] = onTick;
    }
    setState(() => _cooldowns[kind] = seconds);
    _cooldownRefreshers[kind]?.call();
    _cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final active = <_AccountCooldown>[];
      setState(() {
        final done = <_AccountCooldown>[];
        for (final entry in _cooldowns.entries) {
          final next = entry.value - 1;
          if (next <= 0) {
            done.add(entry.key);
          } else {
            _cooldowns[entry.key] = next;
            active.add(entry.key);
          }
        }
        for (final kind in done) {
          _cooldowns.remove(kind);
          active.add(kind);
        }
        if (_cooldowns.isEmpty) {
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
      });
      for (final kind in active) {
        _cooldownRefreshers[kind]?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: _AccountColors.sage600),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: Scaffold(
        backgroundColor: _AccountColors.surface,
        appBar: AppBar(
          backgroundColor: _AccountColors.surface,
          elevation: 0,
          title: const Text('账号管理'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : account == null
            ? _AccountError(message: _error ?? '无法读取账号信息。', onRetry: _load)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (_error != null) ...[
                    _AccountMessage(text: _error!),
                    const SizedBox(height: 14),
                  ],
                  _ProfileCard(
                    account: account,
                    nickname: _nickname,
                    busy: _busy,
                    onSaveNickname: _saveNickname,
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: Icons.lock_outline_rounded, text: '基础操作'),
                  _ActionTile(
                    icon: Icons.mail_outline_rounded,
                    title: '邮箱',
                    subtitle: account.user.email,
                    trailing: '修改',
                    onTap: _busy ? null : _openEmailDialog,
                  ),
                  _ActionTile(
                    icon: Icons.phone_iphone_rounded,
                    title: '手机号',
                    subtitle: account.user.phoneNumber?.isNotEmpty == true
                        ? account.user.phoneNumber!
                        : '未绑定',
                    trailing: '绑定',
                    onTap: _busy ? null : _openPhoneDialog,
                  ),
                  _ActionTile(
                    icon: Icons.password_rounded,
                    title: '密码',
                    subtitle: '通过当前邮箱验证码重置密码',
                    trailing: '重置',
                    onTap: _busy ? null : _openPasswordDialog,
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.verified_user_outlined,
                    text: '多因素验证',
                  ),
                  _ActionTile(
                    icon: Icons.fingerprint_rounded,
                    title: '系统通行密钥',
                    subtitle:
                        '${_passkeys?.credentials.length ?? (account.security.hasPasskey ? 1 : 0)} 个已连接',
                    trailing: '管理',
                    onTap: _busy ? null : _openPasskeyDialog,
                  ),
                  _ActionTile(
                    icon: Icons.shield_outlined,
                    title: 'Authenticator 验证器',
                    subtitle: account.security.hasAuthenticator ? '已连接' : '未设置',
                    trailing: account.security.hasAuthenticator ? '更新' : '设置',
                    onTap: _busy ? null : _openAuthenticatorDialog,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.account,
    required this.nickname,
    required this.busy,
    required this.onSaveNickname,
  });

  final RosmAccountState account;
  final TextEditingController nickname;
  final bool busy;
  final VoidCallback onSaveNickname;

  @override
  Widget build(BuildContext context) {
    final initial = (account.user.email.isNotEmpty ? account.user.email : 'R')
        .characters
        .first
        .toUpperCase();
    return _AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: _AccountColors.sage200,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _AccountColors.sage700,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: nickname,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: '昵称'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSaveNickname(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onSaveNickname,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                text: account.security.mustBindEmail ? '待绑定邮箱' : '邮箱已绑定',
                active: !account.security.mustBindEmail,
              ),
              _StatusPill(
                text: account.security.hasPasskey ? '通行密钥已连接' : '未连接通行密钥',
                active: account.security.hasPasskey,
              ),
              _StatusPill(
                text: account.security.hasAuthenticator ? '验证器已连接' : '未设置验证器',
                active: account.security.hasAuthenticator,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmailSheet extends StatelessWidget {
  const _EmailSheet({
    required this.email,
    required this.currentPassword,
    required this.code,
    required this.busy,
    required this.cooldownLabel,
    required this.sendDisabled,
    required this.onSend,
    required this.onSubmit,
  });

  final TextEditingController email;
  final TextEditingController currentPassword;
  final TextEditingController code;
  final bool busy;
  final String cooldownLabel;
  final bool sendDisabled;
  final VoidCallback onSend;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _CodeSheetFields(
      primary: email,
      primaryLabel: '新邮箱',
      currentPassword: currentPassword,
      code: code,
      codeLabel: '邮箱验证码',
      busy: busy,
      cooldownLabel: cooldownLabel,
      sendDisabled: sendDisabled,
      onSend: onSend,
      onSubmit: onSubmit,
      submitLabel: '完成绑定',
    );
  }
}

class _PhoneSheet extends StatelessWidget {
  const _PhoneSheet({
    required this.phone,
    required this.currentPassword,
    required this.code,
    required this.busy,
    required this.cooldownLabel,
    required this.sendDisabled,
    required this.onSend,
    required this.onSubmit,
  });

  final TextEditingController phone;
  final TextEditingController currentPassword;
  final TextEditingController code;
  final bool busy;
  final String cooldownLabel;
  final bool sendDisabled;
  final VoidCallback onSend;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _CodeSheetFields(
      primary: phone,
      primaryLabel: '手机号',
      currentPassword: currentPassword,
      code: code,
      codeLabel: '短信验证码',
      busy: busy,
      cooldownLabel: cooldownLabel,
      sendDisabled: sendDisabled,
      onSend: onSend,
      onSubmit: onSubmit,
      submitLabel: '完成绑定',
      keyboardType: TextInputType.phone,
    );
  }
}

class _PasswordSheet extends StatelessWidget {
  const _PasswordSheet({
    required this.newPassword,
    required this.code,
    required this.email,
    required this.busy,
    required this.cooldownLabel,
    required this.sendDisabled,
    required this.onSend,
    required this.onSubmit,
  });

  final TextEditingController newPassword;
  final TextEditingController code;
  final String email;
  final bool busy;
  final String cooldownLabel;
  final bool sendDisabled;
  final VoidCallback onSend;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('验证码会发送到当前邮箱：$email'),
        const SizedBox(height: 12),
        TextField(
          controller: newPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码'),
        ),
        const SizedBox(height: 12),
        _CodeRow(
          controller: code,
          label: '邮箱验证码',
          busy: busy,
          cooldownLabel: cooldownLabel,
          sendDisabled: sendDisabled,
          onSend: onSend,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: _BusyText(busy: busy, text: '重置密码'),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child, this.error});

  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final message = error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null && message.isNotEmpty) ...[
          _AccountMessage(text: message),
          const SizedBox(height: 12),
        ],
        child,
      ],
    );
  }
}

class _CodeSheetFields extends StatelessWidget {
  const _CodeSheetFields({
    required this.primary,
    required this.primaryLabel,
    required this.currentPassword,
    required this.code,
    required this.codeLabel,
    required this.busy,
    required this.cooldownLabel,
    required this.sendDisabled,
    required this.onSend,
    required this.onSubmit,
    required this.submitLabel,
    this.keyboardType,
  });

  final TextEditingController primary;
  final String primaryLabel;
  final TextEditingController currentPassword;
  final TextEditingController code;
  final String codeLabel;
  final bool busy;
  final String cooldownLabel;
  final bool sendDisabled;
  final VoidCallback onSend;
  final VoidCallback onSubmit;
  final String submitLabel;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: primary,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: primaryLabel),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: currentPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: '当前密码'),
        ),
        const SizedBox(height: 12),
        _CodeRow(
          controller: code,
          label: codeLabel,
          busy: busy,
          cooldownLabel: cooldownLabel,
          sendDisabled: sendDisabled,
          onSend: onSend,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: _BusyText(busy: busy, text: submitLabel),
        ),
      ],
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.controller,
    required this.label,
    required this.busy,
    required this.cooldownLabel,
    required this.sendDisabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final String label;
  final bool busy;
  final String cooldownLabel;
  final bool sendDisabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 98,
          child: OutlinedButton(
            onPressed: busy || sendDisabled ? null : onSend,
            child: _BusyText(busy: busy, text: cooldownLabel),
          ),
        ),
      ],
    );
  }
}

class _AuthenticatorSheet extends StatelessWidget {
  const _AuthenticatorSheet({
    required this.currentPassword,
    required this.code,
    required this.setup,
    required this.busy,
    required this.onBegin,
    required this.onSubmit,
  });

  final TextEditingController currentPassword;
  final TextEditingController code;
  final RosmAuthenticatorSetup? setup;
  final bool busy;
  final VoidCallback onBegin;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final current = setup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('验证当前密码后，将生成可添加到 Authenticator 应用的密钥。'),
        const SizedBox(height: 12),
        TextField(
          controller: currentPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: '当前密码'),
        ),
        const SizedBox(height: 12),
        if (current == null)
          FilledButton(
            onPressed: busy ? null : onBegin,
            child: _BusyText(busy: busy, text: '生成密钥'),
          )
        else ...[
          _AccountCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('手动输入密钥'),
                const SizedBox(height: 6),
                SelectableText(
                  current.secret,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('otpauth URI'),
                const SizedBox(height: 6),
                SelectableText(current.otpauthUri),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '动态验证码'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : onSubmit,
            child: _BusyText(busy: busy, text: '完成设置'),
          ),
        ],
      ],
    );
  }
}

class _PasskeySheet extends StatelessWidget {
  const _PasskeySheet({
    required this.passkeys,
    required this.currentPassword,
    required this.busy,
    required this.canRegister,
    required this.onRefresh,
    required this.onRegister,
    required this.onDelete,
  });

  final RosmPasskeyList? passkeys;
  final TextEditingController currentPassword;
  final bool busy;
  final bool canRegister;
  final VoidCallback onRefresh;
  final VoidCallback onRegister;
  final void Function(String credentialId) onDelete;

  @override
  Widget build(BuildContext context) {
    final list = passkeys?.credentials ?? const <RosmWebAuthnCredentialInfo>[];
    final max = passkeys?.maxCount ?? 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('已连接 ${list.length} / $max')),
            TextButton(
              onPressed: busy ? null : onRefresh,
              child: const Text('刷新'),
            ),
          ],
        ),
        for (final credential in list)
          _AccountCard(
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    credential.credentialId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => onDelete(credential.credentialId),
                  child: const Text('移除'),
                ),
              ],
            ),
          ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('当前还没有已连接的系统通行密钥。'),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: currentPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: '当前密码'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy || !canRegister || list.length >= max
              ? null
              : onRegister,
          child: _BusyText(
            busy: busy,
            text: !canRegister
                ? '应用未接入通行密钥注册'
                : list.length >= max
                ? '已达上限'
                : '新增通行密钥',
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _AccountCard(
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: _AccountColors.sage600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _AccountColors.sage500),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(color: _AccountColors.sage600),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _AccountColors.sage500),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: _AccountColors.sage500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _AccountColors.sage100),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7F5EA) : const Color(0xFFFFF5D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF287A3E) : const Color(0xFF9A6A00),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BusyText extends StatelessWidget {
  const _BusyText({required this.busy, required this.text});

  final bool busy;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(text);
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _AccountMessage extends StatelessWidget {
  const _AccountMessage({required this.text});

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

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

enum _AccountCooldown { email, phone, password }

String _messageFor(Object error) {
  if (error is RosmApiException) {
    return error.message;
  }
  return error.toString();
}

class _AccountColors {
  const _AccountColors._();

  static const surface = Color(0xFFFAFCFA);
  static const ink = Color(0xFF161D16);
  static const sage100 = Color(0xFFE2E9E2);
  static const sage200 = Color(0xFFC5D3C5);
  static const sage500 = Color(0xFF6E926E);
  static const sage600 = Color(0xFF577557);
  static const sage700 = Color(0xFF415841);
}
