import 'package:flutter/widgets.dart';
import 'password_policy.dart';
import 'primitives.dart';
import 'theme.dart';

class RosemaryFieldRequirement {
  final String id, label;
  final bool Function(String) check;
  const RosemaryFieldRequirement(this.id, this.label, this.check);
  static List<RosemaryFieldRequirement> password({String locale = 'en'}) {
    final labels = locale.startsWith('zh')
        ? RosemaryPasswordPolicy.requirements
        : [
            '8–32 characters',
            'Only English letters, digits and ASCII punctuation; no spaces',
            'At least two of: letters, digits, punctuation',
          ];
    return [
      RosemaryFieldRequirement(
        'length',
        labels[0],
        (v) => RosemaryPasswordPolicy.check(v).length,
      ),
      RosemaryFieldRequirement(
        'characters',
        labels[1],
        (v) => RosemaryPasswordPolicy.check(v).characters,
      ),
      RosemaryFieldRequirement(
        'categories',
        labels[2],
        (v) => RosemaryPasswordPolicy.check(v).categories,
      ),
    ];
  }
}

class RosemaryFieldValidationState {
  bool armed = false, _hadFocus = false;
  void focus() {
    _hadFocus = true;
  }

  void edit(String value) {
    if (value.isEmpty) armed = false;
  }

  void blur(String value, {bool composing = false}) {
    if (value.isEmpty) {
      armed = false;
    } else if (_hadFocus && !composing) {
      armed = true;
    }
    _hadFocus = false;
  }
}

class RosemaryFieldRequirements extends StatelessWidget {
  final String value;
  final List<RosemaryFieldRequirement> requirements;
  final bool active;
  const RosemaryFieldRequirements({
    super.key,
    required this.value,
    required this.requirements,
    required this.active,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in requirements)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (active)
                    RosemaryIcon(
                      rule.check(value) ? 'check' : 'close',
                      size: 16,
                      color: rule.check(value) ? c.muted : c.danger,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Semantics(
                      value: active ? (rule.check(value) ? '✓' : '✕') : null,
                      child: Text(
                        rule.label,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: active && !rule.check(value)
                              ? c.danger
                              : c.muted,
                        ),
                      ),
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
