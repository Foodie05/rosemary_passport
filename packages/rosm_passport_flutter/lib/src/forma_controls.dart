import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'rosm_passport_theme.dart';
import 'epass_brand.dart';

/// Binds legacy controller callbacks to Forma's controlled input contract.
class RosmEpassInput extends StatelessWidget {
  const RosmEpassInput({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines = 1,
    this.autofillHints,
  });
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool? enabled;
  final bool obscureText, readOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final int? maxLines, minLines;
  final Iterable<String>? autofillHints;
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final label = decoration.labelText ?? '';
      final hints =
          autofillHints ??
          (obscureText
              ? const [AutofillHints.password]
              : label.contains('验证码')
              ? const [AutofillHints.oneTimeCode]
              : keyboardType == TextInputType.emailAddress
              ? const [AutofillHints.email]
              : keyboardType == TextInputType.phone
              ? const [AutofillHints.telephoneNumberNational]
              : null);
      // Official 0.4.0 does not expose autofill or IME actions. Keep a native
      // editor for these capabilities, with the same top label and tokens.
      if (hints != null || textInputAction != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RosemaryText(label, role: 'small'),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              readOnly: readOnly,
              obscureText: obscureText,
              autofillHints: hints,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              minLines: minLines,
              maxLines: maxLines,
              autocorrect: !obscureText,
              enableSuggestions: !obscureText,
              style: rosemaryTextStyle(context, 'body'),
              decoration: decoration.copyWith(
                labelText: label,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        );
      }
      return RosemaryInput(
        label: decoration.labelText ?? '',
        placeholder: decoration.hintText ?? '',
        value: value.text,
        enabled: enabled ?? true,
        readOnly: readOnly,
        password: obscureText,
        keyboardType: keyboardType,
        focusNode: focusNode,
        error: decoration.errorText,
        minLines: minLines ?? 1,
        maxLines: maxLines ?? 8,
        onCommit: () => onSubmitted?.call(controller.text),
        onChanged: (text) {
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          onChanged?.call(text);
        },
      );
    },
  );
}

class RosmEpassTextButton extends StatelessWidget {
  const RosmEpassTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  @override
  Widget build(BuildContext context) => RosemaryActionSurface(
    onActivate: onPressed,
    enabled: onPressed != null,
    link: true,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: child,
  );
}

class RosmEpassOutlinedButton extends StatelessWidget {
  const RosmEpassOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return RosemaryActionSurface(
      onActivate: onPressed,
      enabled: onPressed != null,
      background: c.surface,
      foreground: c.ink,
      border: c.control,
      child: child,
    );
  }
}

class RosmEpassBrand extends StatelessWidget {
  const RosmEpassBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (compact)
      return Semantics(
        label: 'Epass',
        excludeSemantics: true,
        child: _brandGraphic(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size.square(32),
                painter: _EpassBadge(
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Epass',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    return Semantics(
      label: 'Rosemary Epass',
      excludeSemantics: true,
      child: _brandGraphic(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/rosemary.png',
              package: 'rosm_passport_flutter',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rosemary',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19.2,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2.56),
                Text(
                  'Epass',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 35.84,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // A brand lockup is a graphic: keep its mandated type/logo proportions.
  // Its accessible name remains a separate, unscaled semantic label.
  Widget _brandGraphic(Widget child) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: MediaQuery.withNoTextScaling(child: child),
  );
}

// Product-approved rounded, tonal badge, generated from the shared geometry.
class _EpassBadge extends CustomPainter {
  const _EpassBadge(this.color, this.onPrimary);
  final Color color, onPrimary;
  @override
  void paint(Canvas canvas, Size size) =>
      paintEpassBadge(canvas, size, color, onPrimary);
  @override
  bool shouldRepaint(_EpassBadge oldDelegate) =>
      oldDelegate.color != color || oldDelegate.onPrimary != onPrimary;
}

Future<T?> showRosmEpassDialog<T>({
  required BuildContext context,
  required String title,
  required ThemeData theme,
  required Widget Function(BuildContext, ValueChanged<T?>) builder,
  bool dismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  transitionDuration: Duration.zero,
  pageBuilder: (routeContext, _, _) => RosmEpassTheme(
    data: theme,
    child: _EpassDialogRoute<T>(
      title: title,
      builder: builder,
      dismissible: dismissible,
    ),
  ),
);

class _EpassDialogRoute<T> extends StatefulWidget {
  const _EpassDialogRoute({
    required this.title,
    required this.builder,
    required this.dismissible,
  });
  final String title;
  final Widget Function(BuildContext, ValueChanged<T?>) builder;
  final bool dismissible;
  @override
  State<_EpassDialogRoute<T>> createState() => _EpassDialogRouteState<T>();
}

class _EpassDialogRouteState<T> extends State<_EpassDialogRoute<T>> {
  bool open = true;
  T? result;
  void close(T? value) {
    if (!open) return;
    result = value;
    setState(() => open = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && widget.dismissible) close(null);
    },
    child: RosemaryDialog(
      open: open,
      title: widget.title,
      onDismiss: (_) {
        if (widget.dismissible) close(null);
      },
      onAnimationFinished: () {
        if (!open && mounted) Navigator.of(context).pop(result);
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: widget.builder(context, close),
      ),
    ),
  );
}

/// Shared paths where the official icon set covers the action; platform symbols
/// remain only for distinctive capabilities such as biometric authentication.
class RosmEpassIcon extends StatelessWidget {
  const RosmEpassIcon(this.icon, {super.key, this.size, this.color});
  final IconData icon;
  final double? size;
  final Color? color;
  static final names = <IconData, String>{
    Icons.close_rounded: 'close',
    Icons.refresh_rounded: 'refresh',
    Icons.lock_outline: 'lock',
    Icons.lock_outline_rounded: 'lock',
    Icons.mail_outline_rounded: 'mail',
    Icons.person_outline_rounded: 'users',
    Icons.shield_outlined: 'shield',
    Icons.chevron_right_rounded: 'chevron',
    Icons.visibility_outlined: 'eye',
    Icons.visibility_off_outlined: 'eye-off',
    Icons.check: 'check',
  };
  @override
  Widget build(BuildContext context) {
    final name = names[icon];
    return name == null
        ? Icon(icon, size: size, color: color)
        : RosemaryIcon(name, size: size ?? 20, color: color);
  }
}

class RosmEpassIconAction extends StatelessWidget {
  const RosmEpassIconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip = '关闭',
    this.color,
  });
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  @override
  Widget build(BuildContext context) => RosemaryActionSurface(
    onActivate: onPressed,
    enabled: onPressed != null,
    label: tooltip ?? '关闭',
    foreground: color,
    padding: const EdgeInsets.all(10),
    child: icon,
  );
}
