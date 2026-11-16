// Derived from pinned rosemary_ui 0.5.0 primitives.dart; MIT, see vendor license.
// Public subclass: only centre the stretched button's content row.
import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

class RosmEpassButton extends RosemaryButton {
  const RosmEpassButton({
    super.key,
    required super.label,
    super.semanticLabel,
    required super.onPressed,
    super.enabled = true,
    super.busy = false,
    super.variant = RosemaryButtonVariant.primary,
    super.leading,
    super.trailing,
    super.focusNode,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    final background = switch (variant) {
      RosemaryButtonVariant.primary => c.primary,
      RosemaryButtonVariant.danger => c.danger,
      RosemaryButtonVariant.secondary => c.fieldFill,
      _ => Colors.transparent,
    };
    final foreground = switch (variant) {
      RosemaryButtonVariant.primary => c.onPrimary,
      RosemaryButtonVariant.danger => c.onDanger,
      RosemaryButtonVariant.secondary => c.ink,
      _ => c.primary,
    };
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        value: busy ? rString(context, 'Loading') : null,
        child: RosemaryActionSurface(
          label: semanticLabel,
          dimWhenDisabled: !busy,
          onActivate: busy ? null : onPressed,
          enabled: enabled && !busy,
          focusNode: focusNode,
          background: background,
          backgroundInset:
              c.isDark &&
                  !MediaQuery.highContrastOf(context) &&
                  (variant == RosemaryButtonVariant.primary ||
                      variant == RosemaryButtonVariant.danger)
              ? RosemaryTokens
                    .componentTokens['button']!
                    .dimensions['darkFillInset']!
              : 0,
          foreground: foreground,
          padding: EdgeInsets.symmetric(
            horizontal: rosemaryDimension('button', 'paddingInline'),
            vertical: rosemaryDimension('button', 'paddingBlock'),
          ),
          border: null,
          child: Row(
            mainAxisSize:
                constraints.minWidth > 0 && constraints.hasBoundedWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                RosemaryLoading(
                  size: 17,
                  color: foreground,
                  label: rString(context, 'Loading'),
                ),
              if (leading != null && !busy) leading!,
              if (busy || leading != null) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: rosemaryTextStyle(context, 'body', color: foreground)
                      .copyWith(
                        fontSize: rosemaryDimension('button', 'fontSize'),
                        height:
                            rosemaryDimension('button', 'lineHeight') /
                            rosemaryDimension('button', 'fontSize'),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
