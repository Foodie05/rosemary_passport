import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'theme.dart';
import 'primitives.dart';
import 'overlays.dart';
import 'generated/rosemary_tokens.dart';
import 'interaction_tokens.dart';
import 'disclosure_curve.dart';

class RosemaryOption {
  final String id, label;
  final bool enabled;
  const RosemaryOption(this.id, this.label, {this.enabled = true});
}

class RosemaryCheckbox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;
  final String label;
  final bool enabled;
  final String? error;
  const RosemaryCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return Semantics(
      checked: value == true,
      mixed: value == null,
      enabled: enabled,
      child: RosemaryActionSurface(
        button: false,
        selectionPress: true,
        enabled: enabled,
        onActivate: () => onChanged(value != true),
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RosemarySelectionMark(
              child: AnimatedContainer(
                duration: rosemaryDuration(context, 'instantFeedback'),
                curve: const Cubic(.2, .8, .2, 1),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value == false ? c.surface : c.primary,
                  border: Border.all(color: c.control),
                  borderRadius: BorderRadius.circular(
                    RosemaryTokens.controlRadius / 2,
                  ),
                ),
                child: ExcludeSemantics(
                  child: value == false
                      ? null
                      : value == null
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 2,
                            color: c.onPrimary,
                          ),
                        )
                      : RosemaryIcon('check', size: 20, color: c.onPrimary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: RosemaryText(label)),
            if (error != null) RosemaryText(error!, color: c.danger),
          ],
        ),
      ),
    );
  }
}

class RosemaryRadio extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final String label;
  final List<RosemaryOption> options;
  final bool enabled;
  final String? error;
  const RosemaryRadio({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.options,
    this.enabled = true,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return Semantics(
      explicitChildNodes: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RosemaryText(label),
          for (final option in options)
            Semantics(
              checked: value == option.id,
              inMutuallyExclusiveGroup: true,
              enabled: enabled && option.enabled,
              child: RosemaryActionSurface(
                button: false,
                selectionPress: true,
                enabled: enabled && option.enabled,
                onActivate: () => onChanged(option.id),
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RosemarySelectionMark(
                      child: Container(
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.control),
                        ),
                        child: AnimatedContainer(
                          duration: rosemaryDuration(
                            context,
                            'instantFeedback',
                          ),
                          curve: const Cubic(.2, .8, .2, 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: value == option.id
                                ? c.primary
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: RosemaryText(option.label)),
                  ],
                ),
              ),
            ),
          if (error != null) RosemaryText(error!, color: c.danger),
        ],
      ),
    );
  }
}

class RosemarySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final bool enabled, busy;
  final String? error;
  const RosemarySwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
    this.busy = false,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    return Semantics(
      toggled: value,
      enabled: enabled && !busy,
      value: busy ? rString(context, 'Loading') : null,
      child: RosemaryActionSurface(
        button: false,
        enabled: enabled && !busy,
        onActivate: () => onChanged(!value),
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: rosemaryDuration(context, 'state'),
              curve: const Cubic(.2, .8, .2, 1),
              width: 44,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? c.primary : c.control,
                borderRadius: BorderRadius.circular(99),
              ),
              child: AnimatedAlign(
                duration: rosemaryDuration(context, 'state'),
                curve: const Cubic(.2, .8, .2, 1),
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? c.onPrimary : c.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: RosemaryText(label)),
            if (error != null) RosemaryText(error!, color: c.danger),
          ],
        ),
      ),
    );
  }
}

class RosemarySlider extends StatefulWidget {
  final double value, min, max, step;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onCommit;
  final bool enabled;
  const RosemarySlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.onCommit,
    this.enabled = true,
  });
  @override
  State<RosemarySlider> createState() => _SliderState();
}

class _SliderState extends State<RosemarySlider> {
  bool dragging = false;
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  double get value => widget.value;
  double get min => widget.min;
  double get max => widget.max;
  double get step => widget.step;
  String get label => widget.label;
  bool get enabled => widget.enabled;
  ValueChanged<double> get onChanged => widget.onChanged;
  ValueChanged<double>? get onCommit => widget.onCommit;
  @override
  Widget build(BuildContext context) {
    if (![value, min, max, step].every((v) => v.isFinite) ||
        max <= min ||
        step <= 0)
      throw ArgumentError(
        'Slider requires finite increasing range and positive step',
      );
    final c = RosemaryThemeData.of(context),
        rtl = Directionality.of(context) == TextDirection.rtl;
    double normalized(double v) =>
        (min + ((v.clamp(min, max) - min) / step).round() * step).clamp(
          min,
          max,
        );
    void update(double v, {bool commit = false}) {
      if (!enabled) return;
      final next = normalized(v);
      onChanged(next);
      if (commit) onCommit?.call(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RosemaryText('$label: $value'),
        Semantics(
          slider: true,
          label: label,
          value: '$value',
          increasedValue: '${normalized(value + step)}',
          decreasedValue: '${normalized(value - step)}',
          onIncrease: enabled ? () => update(value + step, commit: true) : null,
          onDecrease: enabled ? () => update(value - step, commit: true) : null,
          child: Focus(
            focusNode: focus,
            canRequestFocus: enabled,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent || !enabled)
                return KeyEventResult.ignored;
              final key = event.logicalKey;
              double? target;
              if (key == LogicalKeyboardKey.home) target = min;
              if (key == LogicalKeyboardKey.end) target = max;
              if (key == LogicalKeyboardKey.arrowUp) target = value + step;
              if (key == LogicalKeyboardKey.arrowDown) target = value - step;
              if (key == LogicalKeyboardKey.arrowRight)
                target = value + (rtl ? -step : step);
              if (key == LogicalKeyboardKey.arrowLeft)
                target = value + (rtl ? step : -step);
              if (target == null) return KeyEventResult.ignored;
              update(target, commit: true);
              return KeyEventResult.handled;
            },
            child: LayoutBuilder(
              builder: (context, bounds) {
                final inset = rosemaryDimension('slider', 'trackInset');
                final thumb = rosemaryDimension('slider', 'thumbSize');
                final rail = rosemaryDimension('slider', 'trackHeight');
                final travel = (bounds.maxWidth - inset * 2).clamp(
                  0.0,
                  double.infinity,
                );
                final ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);
                final duration = Duration(
                  milliseconds: dragging || c.reduceMotion
                      ? 0
                      : RosemaryInteraction.layoutMs.toInt(),
                );
                void fromX(double x, {bool commit = false}) {
                  final fraction = travel == 0
                      ? 0.0
                      : ((x - inset) / travel).clamp(0.0, 1.0);
                  update(
                    min + (rtl ? 1 - fraction : fraction) * (max - min),
                    commit: commit,
                  );
                }

                return Opacity(
                  opacity: enabled ? 1 : .5,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: enabled ? (_) => focus.requestFocus() : null,
                    onTapUp: enabled
                        ? (d) => fromX(d.localPosition.dx, commit: true)
                        : null,
                    onHorizontalDragStart: enabled
                        ? (_) {
                            focus.requestFocus();
                            setState(() => dragging = true);
                          }
                        : null,
                    onHorizontalDragUpdate: enabled
                        ? (d) => fromX(d.localPosition.dx)
                        : null,
                    onHorizontalDragCancel: () =>
                        setState(() => dragging = false),
                    onHorizontalDragEnd: enabled
                        ? (_) {
                            setState(() => dragging = false);
                            onCommit?.call(normalized(value));
                          }
                        : null,
                    child: SizedBox(
                      height: 44,
                      width: bounds.maxWidth,
                      child: Stack(
                        children: [
                          Positioned(
                            left: inset,
                            right: inset,
                            top: (44 - rail) / 2,
                            child: Container(
                              height: rail,
                              decoration: BoxDecoration(
                                color: c.control,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          AnimatedPositionedDirectional(
                            duration: duration,
                            curve: const Cubic(.2, .8, .2, 1),
                            start: inset,
                            top: (44 - rail) / 2,
                            width: travel * ratio,
                            height: rail,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          AnimatedPositionedDirectional(
                            duration: duration,
                            curve: const Cubic(.2, .8, .2, 1),
                            start: travel * ratio,
                            top: (44 - thumb) / 2,
                            width: thumb,
                            height: thumb,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: c.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class RosemarySelect extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final List<RosemaryOption> options;
  final String label;
  final bool enabled;
  final String? error;
  final ValueChanged<bool>? onOpenChanged;
  const RosemarySelect({
    super.key,
    required this.value,
    required this.onChanged,
    required this.options,
    required this.label,
    this.enabled = true,
    this.error,
    this.onOpenChanged,
  });
  @override
  State<RosemarySelect> createState() => _SelectState();
}

class _SelectState extends State<RosemarySelect>
    with SingleTickerProviderStateMixin {
  late final AnimationController disclosure;
  @override
  void initState() {
    super.initState();
    disclosure = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: RosemaryInteraction.disclosureMs.toInt(),
      ),
      reverseDuration: Duration(
        milliseconds: RosemaryInteraction.disclosureExitMs.toInt(),
      ),
    );
  }

  bool closing = false;
  bool openingUp = false;
  bool get expanded => entry != null && !closing;
  final trigger = FocusNode(), menu = FocusNode();
  final anchor = GlobalKey();
  final optionKeys = <String, GlobalKey>{};
  OverlayEntry? entry;
  int active = 0;
  String prefix = '';
  DateTime last = DateTime.fromMillisecondsSinceEpoch(0);
  List<int> get enabledIndices => [
    for (var i = 0; i < widget.options.length; i++)
      if (widget.options[i].enabled) i,
  ];
  void _close() {
    if (entry == null || closing) return;
    setState(() => closing = true);
    entry?.markNeedsBuild();
    trigger.requestFocus();
    widget.onOpenChanged?.call(false);
    void remove() {
      if (!mounted || !closing) return;
      entry?.remove();
      entry?.dispose();
      entry = null;
      setState(() => closing = false);
    }

    if (RosemaryThemeData.of(context).reduceMotion) {
      disclosure.value = 0;
      remove();
    } else {
      disclosure
          .animateBack(
            0,
            duration: Duration(
              milliseconds: RosemaryInteraction.disclosureExitMs.toInt(),
            ),
            curve: const RosemaryDisclosureCurve(false),
          )
          .then((_) => remove());
    }
  }

  void _open() {
    if (!widget.enabled || enabledIndices.isEmpty) return;
    if (entry != null) {
      if (closing) {
        setState(() => closing = false);
        disclosure.animateTo(
          1,
          duration: Duration(
            milliseconds: RosemaryInteraction.disclosureMs.toInt(),
          ),
          curve: const RosemaryDisclosureCurve(true),
        );
        menu.requestFocus();
        entry?.markNeedsBuild();
        widget.onOpenChanged?.call(true);
      }
      return;
    }
    closing = false;
    if (RosemaryThemeData.of(context).reduceMotion) {
      disclosure.value = 1;
    } else {
      disclosure.animateTo(
        1,
        duration: Duration(
          milliseconds: RosemaryInteraction.disclosureMs.toInt(),
        ),
        curve: const RosemaryDisclosureCurve(true),
      );
    }
    active = widget.options.indexWhere(
      (o) => o.id == widget.value && o.enabled,
    );
    if (active < 0) active = enabledIndices.first;
    entry = OverlayEntry(
      builder: (overlayContext) =>
          RosemaryOverlaySnapshot.capture(
            context,
            Overlay.of(context).context,
          ).wrap(
            Stack(
              children: [
                if (!closing)
                  Positioned.fill(
                    child: _AnchorPassThrough(
                      anchor: anchor,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                RosemaryAnchoredOverlay(
                  anchor: anchor,
                  joined: true,
                  reveal: disclosure,
                  onDirectionChanged: (up) {
                    if (mounted) {
                      setState(() => openingUp = up);
                      entry?.markNeedsBuild();
                    }
                  },
                  child: ExcludeSemantics(
                    excluding: closing,
                    child: IgnorePointer(
                      ignoring: closing,
                      child: Focus(
                        focusNode: menu,
                        autofocus: true,
                        onKeyEvent: _key,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 24,
                              maxHeight: rosemaryDimension(
                                'select',
                                'popupMaxHeight',
                              ),
                            ),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: RosemaryThemeData.of(context).fieldHover,
                              boxShadow: [
                                BoxShadow(
                                  color: RosemaryThemeData.of(
                                    context,
                                  ).ink.withValues(alpha: 0.16),
                                  blurRadius: 38,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                              borderRadius: openingUp
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(
                                        RosemaryTokens.controlRadius,
                                      ),
                                    )
                                  : const BorderRadius.vertical(
                                      bottom: Radius.circular(
                                        RosemaryTokens.controlRadius,
                                      ),
                                    ),
                              border: MediaQuery.highContrastOf(context)
                                  ? Border.all(
                                      color: RosemaryThemeData.of(
                                        context,
                                      ).control,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = 0;
                                    i < widget.options.length;
                                    i++
                                  )
                                    RosemaryActionSurface(
                                      key: optionKeys.putIfAbsent(
                                        widget.options[i].id,
                                        () => GlobalKey(),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      selected:
                                          widget.options[i].id == widget.value,
                                      enabled: widget.options[i].enabled,
                                      background: i == active
                                          ? RosemaryThemeData.of(
                                              context,
                                            ).primarySoft
                                          : null,
                                      onActivate: () {
                                        widget.onChanged(widget.options[i].id);
                                        _close();
                                      },
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.options[i].label,
                                              style:
                                                  rosemaryTextStyle(
                                                    context,
                                                    'small',
                                                  ).copyWith(
                                                    fontSize: 13,
                                                    height: 1.5,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox.square(
                                            dimension: 18,
                                            child:
                                                widget.options[i].id ==
                                                    widget.value
                                                ? const RosemaryIcon(
                                                    'check',
                                                    size: 18,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
    Overlay.of(context).insert(entry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && entry != null) menu.requestFocus();
    });
    setState(() {});
    widget.onOpenChanged?.call(true);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final indices = enabledIndices;
    if (indices.isEmpty) {
      _close();
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.tab) {
      _close();
      return key == LogicalKeyboardKey.tab
          ? KeyEventResult.ignored
          : KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (!indices.contains(active)) active = indices.first;
      widget.onChanged(widget.options[active].id);
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home)
      active = indices.first;
    else if (key == LogicalKeyboardKey.end)
      active = indices.last;
    else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final position = indices.indexOf(active);
      active =
          indices[(position + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
              indices.length];
    } else if (event.character != null && event.character!.length == 1) {
      final now = DateTime.now();
      prefix = now.difference(last).inMilliseconds < 700
          ? prefix + event.character!.toLowerCase()
          : event.character!.toLowerCase();
      last = now;
      final match = indices.where(
        (i) => widget.options[i].label.toLowerCase().startsWith(prefix),
      );
      if (match.isNotEmpty) active = match.first;
    } else {
      return KeyEventResult.ignored;
    }
    entry?.markNeedsBuild();
    _showActive();
    return KeyEventResult.handled;
  }

  void _showActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          entry == null ||
          active < 0 ||
          active >= widget.options.length)
        return;
      final item = optionKeys[widget.options[active].id]?.currentContext;
      if (item != null) Scrollable.ensureVisible(item, alignment: .5);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (entry != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) entry?.markNeedsBuild();
      });
  }

  @override
  void didUpdateWidget(RosemarySelect old) {
    super.didUpdateWidget(old);
    final oldId = active >= 0 && active < old.options.length
        ? old.options[active].id
        : null;
    active = widget.options.indexWhere((o) => o.id == oldId && o.enabled);
    if (active < 0 && enabledIndices.isNotEmpty) active = enabledIndices.first;
    if (enabledIndices.isEmpty && entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    if (!widget.enabled && entry != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        entry?.markNeedsBuild();
        _showActive();
      }
    });
  }

  @override
  void dispose() {
    disclosure.dispose();
    entry?.remove();
    entry?.dispose();
    trigger.dispose();
    menu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options
        .where((o) => o.id == widget.value)
        .firstOrNull;
    return AnimatedBuilder(
      animation: disclosure,
      builder: (context, _) => KeyedSubtree(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: rosemaryTextStyle(context, 'small').copyWith(
                fontSize: rosemaryDimension('select', 'labelFontSize'),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              expanded: expanded,
              value: selected?.label ?? rString(context, 'Choose'),
              child: Opacity(
                opacity: widget.enabled ? 1 : .65,
                child: RosemaryActionSurface(
                  key: anchor,
                  physicalPress: false,
                  corners: BorderRadius.lerp(
                    BorderRadius.circular(RosemaryTokens.controlRadius),
                    openingUp
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(
                              RosemaryTokens.controlRadius,
                            ),
                          )
                        : const BorderRadius.vertical(
                            top: Radius.circular(RosemaryTokens.controlRadius),
                          ),
                    disclosure.value,
                  ),
                  transitionDuration: Duration.zero,
                  label:
                      '${widget.label}: ${selected?.label ?? rString(context, 'Choose')}',
                  onActivate: expanded ? _close : _open,
                  enabled: widget.enabled,
                  dimWhenDisabled: false,
                  focusNode: trigger,
                  background: !widget.enabled
                      ? RosemaryThemeData.of(context).surfaceInset
                      : widget.error != null
                      ? RosemaryThemeData.of(context).dangerSoft
                      : entry != null
                      ? RosemaryThemeData.of(context).fieldHover
                      : RosemaryThemeData.of(context).fieldFill,
                  foreground: widget.enabled
                      ? RosemaryThemeData.of(context).ink
                      : RosemaryThemeData.of(context).muted,
                  border: widget.error != null
                      ? RosemaryThemeData.of(context).danger
                      : (MediaQuery.highContrastOf(context)
                            ? RosemaryThemeData.of(context).control
                            : null),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          selected?.label ?? rString(context, 'Choose'),
                          style:
                              rosemaryTextStyle(
                                context,
                                'body',
                                color: widget.enabled
                                    ? RosemaryThemeData.of(context).ink
                                    : RosemaryThemeData.of(context).muted,
                              ).copyWith(
                                fontSize: rosemaryDimension(
                                  'select',
                                  'fontSize',
                                ),
                                height: 1.5,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.rotate(
                        angle: disclosure.value * 3.141592653589793,
                        child: const RosemaryIcon('down', size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.error != null)
              RosemaryText(
                widget.error!,
                color: RosemaryThemeData.of(context).danger,
              ),
          ],
        ),
      ),
    );
  }
}

// Keep the joined head interactive while the outside-dismiss barrier is present.
class _AnchorPassThrough extends SingleChildRenderObjectWidget {
  final GlobalKey anchor;
  const _AnchorPassThrough({required this.anchor, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AnchorPassThroughBox(anchor);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _AnchorPassThroughBox renderObject,
  ) {
    renderObject.anchor = anchor;
  }
}

class _AnchorPassThroughBox extends RenderProxyBox {
  GlobalKey anchor;
  _AnchorPassThroughBox(this.anchor);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final box = anchor.currentContext?.findRenderObject();
    if (box is RenderBox &&
        box.hasSize &&
        (globalToLocal(box.localToGlobal(Offset.zero)) & box.size).contains(
          position,
        ))
      return false;
    return super.hitTest(result, position: position);
  }
}
