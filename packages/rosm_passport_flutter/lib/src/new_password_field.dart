import 'forma_controls.dart';
import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

import 'password_policy.dart';

/// New-password input with immediate, local feedback and password-manager autofill.
/// Existing login passwords must use an unrestricted field instead.
class RosmNewPasswordField extends StatefulWidget {
  const RosmNewPasswordField({
    super.key,
    required this.controller,
    this.label = '设置密码',
    this.enabled = true,
    this.personalInfo = const [],
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final List<TextEditingController> personalInfo;
  final ValueChanged<String>? onChanged;

  @override
  State<RosmNewPasswordField> createState() => _RosmNewPasswordFieldState();
}

class _RosmNewPasswordFieldState extends State<RosmNewPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, ...widget.personalInfo]),
      builder: (context, _) {
        const policy = RosmPasswordPolicy();
        final value = widget.controller.text;
        final result = policy.evaluate(value);
        final colors = Theme.of(context).colorScheme;
        final personal = policy.containsPersonalInfo(
          value,
          widget.personalInfo.map((controller) => controller.text),
        );
        final checks = <(String, bool)>[
          ('不少于 8 个字符', result.lengthValid),
          ('字母、数字、符号中至少包含两种', result.compositionValid),
          ('英文字母、数字或符号，首尾无空格', result.formatValid),
          ('避开常见弱密码和连续、重复模式', result.uncommon),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RosemaryText(widget.label, role: 'small'),
            const SizedBox(height: 4),
            TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              obscureText: !_visible,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                hintText: widget.label,
                semanticCounterText: widget.label,
                prefixIcon: const RosmEpassIcon(Icons.lock_outline, size: 20),
                enabledBorder: value.isNotEmpty && !result.ok
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.error),
                      )
                    : null,
                suffixIcon: RosmEpassIconAction(
                  tooltip: _visible ? '隐藏密码' : '显示密码',
                  onPressed: widget.enabled
                      ? () => setState(() => _visible = !_visible)
                      : null,
                  icon: RosmEpassIcon(
                    _visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final check in checks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  label:
                      '${check.$1}${value.isNotEmpty && check.$2 ? '，已满足' : ''}',
                  excludeSemantics: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RosmEpassIcon(
                        value.isNotEmpty && check.$2
                            ? Icons.check
                            : Icons.circle_outlined,
                        size: 16,
                        color: value.isNotEmpty && check.$2
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          check.$1,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Semantics(
              liveRegion: true,
              child: Text(
                value.isEmpty ? '输入时会即时检查密码要求。' : result.message ?? '已满足密码要求。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: value.isNotEmpty && !result.ok
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              personal
                  ? '建议避开昵称、邮箱或手机号等个人信息。可使用密码管理器生成和保存。'
                  : '建议使用独立密码，不与其他账户共用。可使用密码管理器生成和保存。',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
