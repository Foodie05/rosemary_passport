import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'forma_controls.dart';
import 'models.dart';
import 'rosm_passport_client.dart';
import 'step_up.dart';

/// Native proof editor. Passkeys remain available to custom UI providers through
/// the client API; this editor exposes only implemented native factors.
class RosmAccountStepUp extends StatefulWidget {
  const RosmAccountStepUp({
    super.key,
    required this.client,
    required this.methods,
    required this.excludedFactor,
    required this.onChanged,
    this.enabled = true,
    this.resetToken,
  });
  final RosmPassportClient client;
  final List<String> methods;
  final String excludedFactor;
  final ValueChanged<RosmStepUpProof?> onChanged;
  final bool enabled;
  final String? resetToken;
  @override
  State<RosmAccountStepUp> createState() => _AccountStepUpState();
}

class _AccountStepUpState extends State<RosmAccountStepUp> {
  static const factors = {
    'password': 'password',
    'email_code': 'email',
    'phone_code': 'phone',
    'authenticator': 'authenticator',
  };
  static const labels = {
    'password': '当前密码',
    'email_code': '当前邮箱验证码',
    'phone_code': '当前手机验证码',
    'authenticator': 'Authenticator 动态码',
  };
  final _input = TextEditingController();
  final _cooldowns = <String, int>{};
  String? _selected, _error;
  bool _busy = false;
  Timer? _timer;
  List<String> get available => widget.methods
      .where(
        (method) =>
            factors.containsKey(method) &&
            factors[method] != widget.excludedFactor,
      )
      .toList();
  @override
  void initState() {
    super.initState();
    _selected = available.firstOrNull;
  }

  @override
  void didUpdateWidget(covariant RosmAccountStepUp old) {
    super.didUpdateWidget(old);
    if (!available.contains(_selected)) {
      _selected = available.firstOrNull;
      _input.clear();
      widget.onChanged(null);
    }
    if (widget.resetToken != old.resetToken && widget.resetToken != null) {
      _input.clear();
      widget.onChanged(null);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  void changed(String value) {
    final code = value.trim();
    widget.onChanged(
      _selected == 'password'
          ? (value.isEmpty ? null : RosmStepUpProof.password(value))
          : !RegExp(r'^\d{6}$').hasMatch(code)
          ? null
          : switch (_selected) {
              'email_code' => RosmStepUpProof.emailCode(code),
              'phone_code' => RosmStepUpProof.phoneCode(code),
              'authenticator' => RosmStepUpProof.authenticator(code),
              _ => null,
            },
    );
  }

  Future<void> send() async {
    final method = _selected;
    if (_busy || !widget.enabled || method == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _input.clear();
    });
    widget.onChanged(null);
    try {
      final result = await widget.client.sendAccountStepUpCode(
        method: method,
        excludedFactor: widget.excludedFactor,
      );
      if (!mounted) return;
      setState(() => _cooldowns[method] = result.retryAfter ?? 60);
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          for (final key in _cooldowns.keys.toList()) {
            _cooldowns[key] = (_cooldowns[key]! - 1).clamp(0, 3600);
          }
        });
        if (_cooldowns.values.every((value) => value == 0)) {
          _timer?.cancel();
          _timer = null;
        }
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is RosmApiException
              ? error.message
              : '验证码发送失败，请重试。',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = _selected;
    if (method == null)
      return const RosemaryAlert(
        '没有可用的原生验证方式，请在账户中心检查已绑定的方式。',
        tone: RosemaryTone.warning,
      );
    final remaining = _cooldowns[method] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RosemarySelect(
          label: '账户二次验证方式',
          value: method,
          enabled: widget.enabled && !_busy,
          options: available
              .map((value) => RosemaryOption(value, labels[value]!))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selected = value;
              _input.clear();
              _error = null;
            });
            widget.onChanged(null);
          },
        ),
        const SizedBox(height: 12),
        RosmEpassInput(
          controller: _input,
          enabled: widget.enabled && !_busy,
          obscureText: method == 'password',
          keyboardType: method == 'password'
              ? TextInputType.visiblePassword
              : TextInputType.number,
          onChanged: changed,
          decoration: InputDecoration(labelText: labels[method]),
          verification: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (method == 'email_code' || method == 'phone_code')
                RosmEpassOutlinedButton(
                  onPressed: !widget.enabled || _busy || remaining > 0
                      ? null
                      : send,
                  child: Text(
                    _busy
                        ? '发送中…'
                        : remaining > 0
                        ? '$remaining 秒后重发'
                        : '发送身份验证码',
                  ),
                ),
              if (_error != null || widget.resetToken != null)
                RosemaryAlert(
                  _error ?? widget.resetToken!,
                  tone: RosemaryTone.danger,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const RosemaryText('使用其他已绑定方式验证本次更改。', role: 'small'),
      ],
    );
  }
}
