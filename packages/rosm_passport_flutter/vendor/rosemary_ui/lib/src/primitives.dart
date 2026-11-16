import 'package:flutter/physics.dart';
import 'validation.dart';
import 'interaction_tokens.dart';
import 'field_outline.dart';
import 'overlays.dart';
import 'dart:ui' show SemanticsValidationResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'feedback.dart';
import 'generated/rosemary_tokens.dart';
import 'generated/rosemary_icons.dart';

enum RosemaryButtonVariant { primary, secondary, text, danger }

class _ActionKeyIntent extends Intent {
  final LogicalKeyboardKey key;
  final bool down;
  const _ActionKeyIntent(this.key, this.down);
}

class _ActionKeyActivator extends ShortcutActivator {
  final LogicalKeyboardKey key;
  final bool down;
  const _ActionKeyActivator(this.key, this.down);
  @override
  Iterable<LogicalKeyboardKey> get triggers => [key];
  @override
  String debugDescribeKeys() => '${key.keyLabel} ${down ? "down" : "up"}';
  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      event.logicalKey == key &&
      !state.isControlPressed &&
      !state.isAltPressed &&
      !state.isMetaPressed &&
      (down
          ? event is KeyDownEvent || event is KeyRepeatEvent
          : event is KeyUpEvent);
}

class RosemaryActionSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onActivate;
  final FocusNode? focusNode;
  final String? label;
  final Color? background, foreground, border;
  final bool selected,
      link,
      button,
      enabled,
      dimWhenDisabled,
      physicalPress,
      selectionPress;
  final double? radius;
  final BorderRadius? corners;
  final Duration? transitionDuration;
  final Curve transitionCurve;
  final double backgroundInset;
  final EdgeInsetsGeometry padding;
  final Key? semanticsKey;
  const RosemaryActionSurface({
    super.key,
    required this.child,
    this.onActivate,
    this.focusNode,
    this.label,
    this.background,
    this.foreground,
    this.border,
    this.selected = false,
    this.link = false,
    this.button = true,
    this.enabled = true,
    this.dimWhenDisabled = true,
    this.physicalPress = true,
    this.selectionPress = false,
    this.radius,
    this.corners,
    this.transitionDuration,
    this.transitionCurve = const Cubic(.2, .8, .2, 1),
    this.backgroundInset = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.semanticsKey,
  });
  @override
  State<RosemaryActionSurface> createState() => _ActionSurfaceState();
}

class _ActionSurfaceState extends State<RosemaryActionSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController physical = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  void press(bool held) {
    if (!widget.physicalPress || RosemaryThemeData.of(context).reduceMotion) {
      physical.stop();
      physical.value = 1;
      return;
    }
    physical.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: held
              ? RosemaryInteraction.pressStiffness
              : RosemaryInteraction.releaseStiffness,
          ratio: held
              ? RosemaryInteraction.pressDamping
              : RosemaryInteraction.releaseDamping,
        ),
        physical.value,
        held
            ? (widget.selectionPress
                  ? RosemaryInteraction.selectionScale
                  : RosemaryInteraction.pressScale)
            : 1,
        physical.velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(RosemaryActionSurface old) {
    super.didUpdateWidget(old);
    if (!widget.enabled || widget.onActivate == null) {
      heldKey = null;
      pressed = false;
      physical.stop();
      physical.value = 1;
    }
  }

  @override
  void dispose() {
    physical.dispose();
    super.dispose();
  }

  LogicalKeyboardKey? heldKey;
  bool focused = false, hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    final enabled = widget.enabled && widget.onActivate != null;
    return Semantics(
      key: widget.semanticsKey,
      button: widget.button,
      link: widget.link,
      label: widget.label,
      enabled: enabled,
      selected: widget.selected,
      onTap: enabled ? widget.onActivate : null,
      excludeSemantics: widget.label != null,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: enabled,
        onFocusChange: (v) {
          if (!v) {
            heldKey = null;
            pressed = false;
            press(false);
          }
          setState(() => focused = v);
        },
        onShowHoverHighlight: (v) => setState(() => hovered = v),
        shortcuts: {
          for (final key in [
            LogicalKeyboardKey.enter,
            if (!widget.link) LogicalKeyboardKey.space,
          ])
            for (final down in [true, false])
              _ActionKeyActivator(key, down): _ActionKeyIntent(key, down),
        },
        actions: {
          _ActionKeyIntent: CallbackAction<_ActionKeyIntent>(
            onInvoke: (intent) {
              if (!enabled) return null;
              if (intent.down && heldKey == null) {
                heldKey = intent.key;
                setState(() => pressed = true);
                press(true);
                if (intent.key == LogicalKeyboardKey.enter)
                  widget.onActivate!();
              } else if (!intent.down && heldKey == intent.key) {
                heldKey = null;
                setState(() => pressed = false);
                press(false);
                if (intent.key == LogicalKeyboardKey.space)
                  widget.onActivate!();
              }
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (enabled) {
                press(true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) press(false);
                });
                widget.onActivate!();
              }
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onActivate : null,
          onTapDown: enabled
              ? (_) {
                  press(true);
                  setState(() => pressed = true);
                }
              : null,
          onTapUp: (_) {
            press(false);
            setState(() => pressed = false);
          },
          onTapCancel: () {
            press(false);
            setState(() => pressed = false);
          },
          excludeFromSemantics: true,
          child: AnimatedBuilder(
            animation: physical,
            builder: (context, child) => Transform.scale(
              scale:
                  widget.selectionPress ||
                      RosemaryThemeData.of(context).reduceMotion
                  ? 1
                  : pressed || physical.isAnimating
                  ? physical.value
                  : 1,
              child: child,
            ),
            child: _RosemaryAnimatedSize(
              duration: rosemaryDuration(context, "state"),
              curve: const Cubic(.2, .8, .2, 1),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(widget.backgroundInset),
                      child: AnimatedContainer(
                        duration:
                            widget.transitionDuration ??
                            rosemaryDuration(context, 'instantFeedback'),
                        curve: widget.transitionCurve,
                        decoration: BoxDecoration(
                          color: widget.background ?? Colors.transparent,
                          borderRadius: _insetCorners(
                            widget.corners ??
                                BorderRadius.circular(
                                  widget.radius ?? RosemaryTokens.controlRadius,
                                ),
                            widget.backgroundInset,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration:
                        widget.transitionDuration ??
                        rosemaryDuration(context, 'instantFeedback'),
                    curve: widget.transitionCurve,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius:
                          widget.corners ??
                          BorderRadius.circular(
                            widget.radius ?? RosemaryTokens.controlRadius,
                          ),
                      border: Border.all(
                        color: focused
                            ? c.focus
                            : widget.border ?? Colors.transparent,
                        width: focused ? 2 : 1,
                      ),
                    ),
                    child: Opacity(
                      opacity:
                          widget.dimWhenDisabled &&
                              (!widget.enabled ||
                                  (widget.button && widget.onActivate == null))
                          ? 0.55
                          : hovered
                          ? 0.92
                          : 1,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: widget.foreground ?? c.ink),
                        child: _RosemarySelectionScope(
                          notifier: physical,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RosemaryButton extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool enabled, busy;
  final RosemaryButtonVariant variant;
  final Widget? leading, trailing;
  final FocusNode? focusNode;
  const RosemaryButton({
    super.key,
    required this.label,
    this.semanticLabel,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
    this.variant = RosemaryButtonVariant.primary,
    this.leading,
    this.trailing,
    this.focusNode,
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
    return Semantics(
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
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class RosemaryIconButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget icon;
  final bool enabled, busy, pressed, danger;
  final FocusNode? focusNode;
  const RosemaryIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.enabled = true,
    this.busy = false,
    this.pressed = false,
    this.danger = false,
    this.focusNode,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return RosemaryActionSurface(
      label: label,
      onActivate: busy ? null : onPressed,
      enabled: enabled && !busy,
      selected: pressed,
      focusNode: focusNode,
      background: pressed ? c.primarySoft : null,
      foreground: danger ? c.danger : c.ink,
      padding: const EdgeInsets.all(10),
      child: ExcludeSemantics(
        child: busy
            ? RosemaryLoading(size: 17, color: danger ? c.danger : c.ink)
            : icon,
      ),
    );
  }
}

class RosemaryLink extends StatelessWidget {
  final String label;
  final VoidCallback onNavigate;
  final bool current;
  const RosemaryLink({
    super.key,
    required this.label,
    required this.onNavigate,
    this.current = false,
  });
  @override
  Widget build(BuildContext context) => RosemaryActionSurface(
    link: true,
    button: false,
    selected: current,
    onActivate: current ? null : onNavigate,
    child: Text(
      label,
      style: TextStyle(
        color: RosemaryThemeData.of(context).primary,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

class RosemaryIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const RosemaryIcon(this.name, {super.key, this.size = 24, this.color});
  @override
  Widget build(BuildContext context) {
    if (!RosemaryIcons.paths.containsKey(name))
      throw ArgumentError.value(name, 'icon');
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _IconPainter(
            name,
            color ??
                DefaultTextStyle.of(context).style.color ??
                RosemaryThemeData.of(context).ink,
          ),
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  final String name;
  final Color color;
  _IconPainter(this.name, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / RosemaryIcons.viewBox,
      size.height / RosemaryIcons.viewBox,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = RosemaryIcons.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final shape in RosemaryIcons.paths[name]!) {
      final path = Path();
      for (final command in shape) {
        final v = command.values;
        switch (command.op) {
          case 'M':
            path.moveTo(v[0], v[1]);
          case 'L':
            path.lineTo(v[0], v[1]);
          case 'C':
            path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
          case 'Z':
            path.close();
          default:
            throw StateError('Unsupported generated icon operation');
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.name != name || old.color != color;
}

class RosemaryInput extends StatefulWidget {
  final String value, label;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final bool enabled, readOnly, password;
  final String? error;
  final TextInputType? keyboardType;
  final VoidCallback? onCommit;
  final FocusNode? focusNode;
  final int minLines, maxLines;
  final List<RosemaryFieldRequirement> requirements;
  final Widget? verification;
  const RosemaryInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.placeholder = '',
    this.enabled = true,
    this.readOnly = false,
    this.password = false,
    this.error,
    this.keyboardType,
    this.onCommit,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 1,
    this.requirements = const [],
    this.verification,
  });
  @override
  State<RosemaryInput> createState() => _InputState();
}

class _InputState extends State<RosemaryInput> {
  late final TextEditingController controller;
  late FocusNode node;
  bool focused = false;
  final validation = RosemaryFieldValidationState();
  bool get active =>
      validation.armed &&
      widget.value.isNotEmpty &&
      controller.value.composing.isCollapsed;
  bool get invalid =>
      widget.error != null ||
      active && widget.requirements.any((r) => !r.check(widget.value));
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
    node = widget.focusNode ?? FocusNode();
    node.addListener(_focus);
    controller.addListener(_edit);
  }

  void _edit() {
    if (!mounted) return;
    validation.edit(controller.text);
    setState(() {});
  }

  void _focus() {
    if (!mounted) return;
    if (node.hasFocus) {
      validation.focus();
    } else {
      validation.blur(
        controller.text,
        composing: !controller.value.composing.isCollapsed,
      );
    }
    setState(() => focused = node.hasFocus);
  }

  @override
  void didUpdateWidget(RosemaryInput old) {
    super.didUpdateWidget(old);
    validation.edit(widget.value);
    if (old.focusNode != widget.focusNode) {
      node.removeListener(_focus);
      if (old.focusNode == null) node.dispose();
      node = widget.focusNode ?? FocusNode();
      node.addListener(_focus);
    }
    if (controller.text != widget.value) {
      final selection = controller.selection;
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(
          offset: selection.extentOffset.clamp(0, widget.value.length),
        ),
      );
    }
  }

  @override
  void dispose() {
    node.removeListener(_focus);
    if (widget.focusNode == null) node.dispose();
    controller.removeListener(_edit);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: rosemaryTextStyle(context, 'small').copyWith(
            fontSize: rosemaryDimension('input', 'labelFontSize'),
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: widget.label,
          validationResult: !invalid
              ? SemanticsValidationResult.none
              : SemanticsValidationResult.invalid,
          child: RosemaryFieldOutline(
            focused: focused,
            invalid: invalid,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: rosemaryDimension('input', 'paddingBlock'),
              ),
              decoration: BoxDecoration(
                color: invalid
                    ? c.dangerSoft
                    : !widget.enabled || widget.readOnly
                    ? c.surfaceInset
                    : c.fieldFill,
                borderRadius: BorderRadius.circular(
                  RosemaryTokens.controlRadius,
                ),
                border: MediaQuery.highContrastOf(context)
                    ? Border.all(
                        color: widget.error != null
                            ? c.danger
                            : focused
                            ? c.focus
                            : c.control,
                        width: 2,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (controller.text.isEmpty && !focused)
                    IgnorePointer(
                      child: Text(
                        widget.placeholder,
                        style:
                            rosemaryTextStyle(
                              context,
                              'body',
                              color: c.muted,
                            ).copyWith(
                              fontSize: rosemaryDimension('input', 'fontSize'),
                              height: 1.5,
                            ),
                      ),
                    ),
                  EditableText(
                    controller: controller,
                    focusNode: node,
                    style: rosemaryTextStyle(context, 'body').copyWith(
                      fontSize: rosemaryDimension('input', 'fontSize'),
                      height:
                          rosemaryDimension('input', 'lineHeight') /
                          rosemaryDimension('input', 'fontSize'),
                    ),
                    cursorColor: c.primary,
                    backgroundCursorColor: c.surface,
                    readOnly: widget.readOnly || !widget.enabled,
                    showCursor: widget.enabled,
                    obscureText: widget.password,
                    keyboardType:
                        widget.keyboardType ??
                        (widget.password
                            ? TextInputType.visiblePassword
                            : null),
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    selectionControls: materialTextSelectionControls,
                    onChanged: (value) {
                      widget.onChanged(value);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && controller.text != widget.value)
                          controller.value = TextEditingValue(
                            text: widget.value,
                            selection: TextSelection.collapsed(
                              offset: widget.value.length,
                            ),
                          );
                      });
                    },
                    onSubmitted: (_) => widget.onCommit?.call(),
                  ),
                ],
              ),
            ),
          ),
        ),
        RosemaryFieldRequirements(
          value: widget.value,
          requirements: widget.requirements,
          active: active,
        ),
        if (widget.verification != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: widget.verification!,
          ),
        if (widget.error != null)
          Semantics(
            liveRegion: true,
            child: RosemaryText(widget.error!, role: 'small', color: c.danger),
          ),
      ],
    );
  }
}

class RosemaryTextarea extends StatelessWidget {
  final String value, label, placeholder;
  final ValueChanged<String> onChanged;
  final bool enabled, readOnly;
  final String? error;
  final int minLines;
  final List<RosemaryFieldRequirement> requirements;
  final Widget? verification;
  const RosemaryTextarea({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.placeholder = '',
    this.enabled = true,
    this.readOnly = false,
    this.error,
    this.minLines = 4,
    this.requirements = const [],
    this.verification,
  });
  @override
  Widget build(BuildContext context) => RosemaryInput(
    value: value,
    onChanged: onChanged,
    label: label,
    placeholder: placeholder,
    enabled: enabled,
    readOnly: readOnly,
    error: error,
    minLines: minLines,
    maxLines: 1000,
    requirements: requirements,
    verification: verification,
  );
}

enum RosemarySearchPresentation { inline, dialog }

class RosemarySearch extends StatefulWidget {
  final String query, label;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onClear;
  final bool busy;
  final RosemarySearchPresentation presentation;
  final bool initiallyExpanded;
  const RosemarySearch({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onSubmit,
    this.label = 'Search',
    this.onClear,
    this.busy = false,
    this.presentation = RosemarySearchPresentation.inline,
    this.initiallyExpanded = true,
  });
  @override
  State<RosemarySearch> createState() => _SearchState();
}

class _SearchState extends State<RosemarySearch> {
  late bool expanded =
      widget.presentation == RosemarySearchPresentation.inline &&
      widget.initiallyExpanded;
  final entryFocus = FocusNode(), fieldFocus = FocusNode();
  String get query => widget.query;
  String get label => widget.label;
  bool get busy => widget.busy;
  ValueChanged<String> get onQueryChanged => widget.onQueryChanged;
  VoidCallback get onSubmit => widget.onSubmit;
  VoidCallback? get onClear => widget.onClear;
  @override
  void dispose() {
    entryFocus.dispose();
    fieldFocus.dispose();
    super.dispose();
  }

  void close() {
    setState(() => expanded = false);
    entryFocus.requestFocus();
  }

  void open() {
    setState(() => expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fieldFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final contents = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (widget.presentation == RosemarySearchPresentation.dialog ||
              query.isEmpty) {
            close();
          } else {
            onQueryChanged('');
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: searchContents(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.presentation == RosemarySearchPresentation.dialog ||
            !expanded)
          RosemaryIconButton(
            label: label,
            icon: const RosemaryIcon('search'),
            focusNode: entryFocus,
            onPressed: open,
          ),
        if (widget.presentation == RosemarySearchPresentation.inline &&
            expanded)
          contents,
        if (widget.presentation == RosemarySearchPresentation.dialog)
          RosemaryDialog(
            open: expanded,
            title: label,
            onDismiss: (_) => close(),
            child: contents,
          ),
      ],
    );
  }

  Widget searchContents(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RosemaryInput(
        value: query,
        focusNode: fieldFocus,
        onChanged: onQueryChanged,
        label: label,
        onCommit: busy ? null : onSubmit,
        keyboardType: TextInputType.text,
      ),
      Wrap(
        spacing: 8,
        children: [
          RosemaryButton(
            label: rString(context, 'Search'),
            onPressed: onSubmit,
            busy: busy,
          ),
          RosemaryButton(
            label: rString(context, 'Clear'),
            variant: RosemaryButtonVariant.text,
            onPressed: query.isEmpty
                ? null
                : () => onClear != null ? onClear!() : onQueryChanged(''),
          ),
        ],
      ),
    ],
  );
}

class _RosemaryAnimatedSize extends StatelessWidget {
  final Duration duration;
  final Curve curve;
  final Widget child;
  const _RosemaryAnimatedSize({
    required this.duration,
    required this.curve,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => duration == Duration.zero
      ? child
      : AnimatedSize(duration: duration, curve: curve, child: child);
}

BorderRadius _insetCorners(BorderRadius corners, double inset) {
  Radius inner(Radius r) => Radius.elliptical(
    (r.x - inset).clamp(0, double.infinity),
    (r.y - inset).clamp(0, double.infinity),
  );
  return BorderRadius.only(
    topLeft: inner(corners.topLeft),
    topRight: inner(corners.topRight),
    bottomLeft: inner(corners.bottomLeft),
    bottomRight: inner(corners.bottomRight),
  );
}

class _RosemarySelectionScope extends InheritedNotifier<Animation<double>> {
  const _RosemarySelectionScope({
    required super.notifier,
    required super.child,
  });
}

/// Paint-only physical feedback; leaves the label and 44px target stationary.
class RosemarySelectionMark extends StatelessWidget {
  final Widget child;
  const RosemarySelectionMark({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RosemarySelectionScope>();
    return Transform.scale(
      scale: RosemaryThemeData.of(context).reduceMotion
          ? 1
          : scope?.notifier?.value ?? 1,
      child: child,
    );
  }
}
