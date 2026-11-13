import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'forma_controls.dart';
import 'password_policy.dart';

/// Creation-only field. The official requirements arm after a nonempty blur.
/// Login fields deliberately do not inherit creation complexity rules.
class RosmNewPasswordField extends StatefulWidget {
  const RosmNewPasswordField({
    super.key,
    required this.controller,
    this.label = '设置密码',
    this.enabled = true,
    this.personalInfo = const [],
    this.onChanged,
    this.verification,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final List<TextEditingController> personalInfo;
  final ValueChanged<String>? onChanged;
  final Widget? verification;
  @override
  State<RosmNewPasswordField> createState() => _RosmNewPasswordFieldState();
}

class _RosmNewPasswordFieldState extends State<RosmNewPasswordField> {
  bool _visible = false;
  static final requirements = [
    ...RosemaryFieldRequirement.password(locale: 'zh'),
    RosemaryFieldRequirement(
      'uncommon',
      '避开常见弱密码和连续、重复模式',
      (value) => const RosmPasswordPolicy().evaluate(value).uncommon,
    ),
  ];
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller, ...widget.personalInfo]),
    builder: (context, _) {
      final personal = const RosmPasswordPolicy().containsPersonalInfo(
        widget.controller.text,
        widget.personalInfo.map((controller) => controller.text),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RosmEpassInput(
            controller: widget.controller,
            enabled: widget.enabled,
            obscureText: !_visible,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: widget.onChanged,
            requirements: requirements,
            verification: widget.verification,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.label,
              prefixIcon: const RosemaryIcon('lock', size: 20),
              suffixIcon: RosmEpassIconAction(
                tooltip: _visible ? '隐藏密码' : '显示密码',
                onPressed: widget.enabled
                    ? () => setState(() => _visible = !_visible)
                    : null,
                icon: RosemaryIcon(_visible ? 'eye-off' : 'eye', size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          RosemaryText(
            personal
                ? '建议避开昵称、邮箱或手机号等个人信息。可使用密码管理器生成和保存。'
                : '建议使用独立密码，不与其他账户共用。可使用密码管理器生成和保存。',
            role: 'small',
          ),
        ],
      );
    },
  );
}
