import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

/// The SDK's checkbox label accepts a string only. Native inline text keeps
/// prose and independent, keyboard-accessible document links on one baseline.
class RosmEpassAgreement extends StatelessWidget {
  const RosmEpassAgreement({
    super.key,
    required this.checked,
    required this.enabled,
    required this.onChanged,
    required this.onTerms,
    required this.onPrivacy,
  });
  final bool checked, enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTerms, onPrivacy;
  @override
  Widget build(BuildContext context) {
    final textStyle = rosemaryTextStyle(
      context,
      'small',
    ).copyWith(fontSize: 14, height: 24 / 14);
    WidgetSpan inline(Widget child) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: child,
    );
    final firstLineHeight =
        MediaQuery.textScalerOf(context).scale(14) * 24 / 14;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onChanged(!checked) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '同意使用条款与隐私政策',
            child: SizedBox(
              width: 32,
              height: (firstLineHeight + 20).clamp(44, double.infinity),
              child: Center(
                child: RosemaryCheckbox(
                  value: checked,
                  enabled: enabled,
                  label: '',
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final links = ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: IntrinsicWidth(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            inline(
                              _InlineAgreementLink(
                                label: '《使用条款》',
                                onTap: onTerms,
                                style: textStyle,
                              ),
                            ),
                            const TextSpan(text: ' 与 '),
                            inline(
                              _InlineAgreementLink(
                                label: '《隐私政策》',
                                onTap: onPrivacy,
                                style: textStyle,
                              ),
                            ),
                          ],
                        ),
                        style: textStyle,
                        strutStyle: StrutStyle.fromTextStyle(
                          textStyle,
                          forceStrutHeight: true,
                        ),
                      ),
                    ),
                  );
                  return Text.rich(
                    TextSpan(
                      children: [
                        inline(Text('我已阅读并同意', style: textStyle)),
                        const TextSpan(text: ' '),
                        inline(links),
                      ],
                    ),
                    style: textStyle,
                    strutStyle: StrutStyle.fromTextStyle(
                      textStyle,
                      forceStrutHeight: true,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAgreementLink extends StatefulWidget {
  const _InlineAgreementLink({
    required this.label,
    required this.onTap,
    required this.style,
  });
  final String label;
  final VoidCallback onTap;
  final TextStyle style;
  @override
  State<_InlineAgreementLink> createState() => _InlineAgreementLinkState();
}

class _InlineAgreementLinkState extends State<_InlineAgreementLink> {
  bool highlight = false;
  @override
  Widget build(BuildContext context) {
    final color = RosemaryThemeData.of(context).primary;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => highlight = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        link: true,
        label: widget.label,
        onTap: widget.onTap,
        child: GestureDetector(
          onTap: widget.onTap,
          excludeFromSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: highlight
                  ? Border.all(
                      color: RosemaryThemeData.of(context).focus,
                      width: 2,
                    )
                  : null,
            ),
            position: DecorationPosition.foreground,
            child: ExcludeSemantics(
              child: Text(
                widget.label,
                style: widget.style.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
