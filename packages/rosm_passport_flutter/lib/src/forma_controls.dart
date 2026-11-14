import 'dart:ui' show SemanticsValidationResult;
import 'forma_field_outline.dart';
import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'rosm_passport_theme.dart';
import 'epass_brand.dart';

/// Uses official controlled fields; adapts only native controller/autofill hooks.
class RosmEpassInput extends StatefulWidget {
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
    this.requirements = const [],
    this.verification,
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
  final List<RosemaryFieldRequirement> requirements;
  final Widget? verification;
  @override
  State<RosmEpassInput> createState() => _RosmEpassInputState();
}

class _RosmEpassInputState extends State<RosmEpassInput> {
  late FocusNode node;
  final validation = RosemaryFieldValidationState();
  @override
  void initState() {
    super.initState();
    node = widget.focusNode ?? FocusNode();
    node.addListener(_focus);
    widget.controller.addListener(_edit);
  }

  void _edit() {
    validation.edit(widget.controller.text);
    if (mounted) setState(() {});
  }

  void _focus() {
    if (node.hasFocus)
      validation.focus();
    else
      validation.blur(
        widget.controller.text,
        composing: !widget.controller.value.composing.isCollapsed,
      );
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RosmEpassInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_edit);
      widget.controller.addListener(_edit);
      validation.edit(widget.controller.text);
    }
    if (old.focusNode != widget.focusNode) {
      node.removeListener(_focus);
      if (old.focusNode == null) node.dispose();
      node = widget.focusNode ?? FocusNode();
      node.addListener(_focus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_edit);
    node.removeListener(_focus);
    if (widget.focusNode == null) node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.decoration.labelText ?? '';
    final hints =
        widget.autofillHints ??
        (widget.obscureText
            ? const [AutofillHints.password]
            : label.contains('验证码')
            ? const [AutofillHints.oneTimeCode]
            : widget.keyboardType == TextInputType.emailAddress
            ? const [AutofillHints.email]
            : widget.keyboardType == TextInputType.phone
            ? const [AutofillHints.telephoneNumberNational]
            : null);
    final value = widget.controller.text;
    final requirements = widget.requirements.isNotEmpty
        ? widget.requirements
        : label.contains('验证码') || label.contains('动态码')
        ? [
            RosemaryFieldRequirement(
              'code',
              '输入 6 位数字验证码',
              (value) => RegExp(r'^\d{6}$').hasMatch(value),
            ),
          ]
        : const <RosemaryFieldRequirement>[];
    final active =
        validation.armed &&
        value.isNotEmpty &&
        widget.controller.value.composing.isCollapsed;
    final emailInvalid =
        active &&
        label.contains('邮箱') &&
        !label.contains('或') &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    final errorText =
        widget.decoration.errorText ?? (emailInvalid ? '邮箱地址格式不正确。' : null);
    if (hints == null &&
        widget.textInputAction == null &&
        widget.decoration.suffixIcon == null &&
        widget.decoration.prefixIcon == null) {
      return RosemaryInput(
        label: label,
        placeholder: widget.decoration.hintText ?? '',
        value: value,
        enabled: widget.enabled ?? true,
        readOnly: widget.readOnly,
        password: widget.obscureText,
        keyboardType: widget.keyboardType,
        focusNode: node,
        error: errorText,
        requirements: requirements,
        verification: widget.verification,
        minLines: widget.minLines ?? 1,
        maxLines: widget.maxLines ?? 8,
        onCommit: () => widget.onSubmitted?.call(widget.controller.text),
        onChanged: (text) {
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          widget.onChanged?.call(text);
        },
      );
    }
    final c = RosemaryThemeData.of(context);
    final invalid =
        errorText != null ||
        (active && requirements.any((rule) => !rule.check(value)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: rosemaryTextStyle(
            context,
            'small',
          ).copyWith(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: label,
          validationResult: invalid
              ? SemanticsValidationResult.invalid
              : SemanticsValidationResult.none,
          child: RosmFieldOutline(
            focused: node.hasFocus,
            invalid: invalid,
            child: TextField(
              controller: widget.controller,
              focusNode: node,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              obscureText: widget.obscureText,
              autofillHints: hints,
              textInputAction: widget.textInputAction,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              autocorrect: !widget.obscureText,
              enableSuggestions: !widget.obscureText,
              style: rosemaryTextStyle(
                context,
                'body',
              ).copyWith(fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: widget.decoration.hintText,
                prefixIcon: widget.decoration.prefixIcon,
                suffixIcon: widget.decoration.suffixIcon,
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: true,
                fillColor: invalid
                    ? c.dangerSoft
                    : widget.enabled == false || widget.readOnly
                    ? c.surfaceInset
                    : c.fieldFill,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        RosemaryFieldRequirements(
          value: value,
          requirements: requirements,
          active: active,
        ),
        if (widget.verification != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: widget.verification,
          ),
        if (errorText != null)
          RosemaryText(errorText, role: 'small', color: c.danger),
      ],
    );
  }
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
    child: DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: rosemaryDimension('button', 'fontSize'),
        height:
            rosemaryDimension('button', 'lineHeight') /
            rosemaryDimension('button', 'fontSize'),
        fontWeight: FontWeight.w500,
      ),
      child: child,
    ),
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
      background: c.fieldFill,
      foreground: c.ink,
      padding: EdgeInsets.symmetric(
        horizontal: rosemaryDimension('button', 'paddingInline'),
        vertical: rosemaryDimension('button', 'paddingBlock'),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: rosemaryDimension('button', 'fontSize'),
          height:
              rosemaryDimension('button', 'lineHeight') /
              rosemaryDimension('button', 'fontSize'),
          fontWeight: FontWeight.w500,
        ),
        child: child,
      ),
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

/// Map legacy public IconData callers onto the official Rosemary icon set.
class RosmEpassIcon extends StatelessWidget {
  const RosmEpassIcon(this.icon, {super.key, this.size, this.color});
  final IconData icon;
  final double? size;
  final Color? color;
  static final names = <IconData, String>{
    Icons.check_circle_rounded: 'check',
    Icons.verified_user_outlined: 'shield-check',
    Icons.password_rounded: 'lock',
    Icons.phone_iphone_rounded: 'message',
    Icons.pin_outlined: 'key',
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
    return RosemaryIcon(names[icon] ?? 'info', size: size ?? 20, color: color);
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
