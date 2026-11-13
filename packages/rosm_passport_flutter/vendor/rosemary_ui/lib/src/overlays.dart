import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'generated/rosemary_tokens.dart';

/// Keeps a non-modal popup inside its owning window, flipping above if needed.
class RosemaryAnchoredOverlay extends StatefulWidget {
  final GlobalKey anchor;
  final Widget child;
  final bool joined;
  final Animation<double>? reveal;
  final ValueChanged<bool>? onDirectionChanged;
  const RosemaryAnchoredOverlay({
    super.key,
    required this.anchor,
    required this.child,
    this.joined = false,
    this.reveal,
    this.onDirectionChanged,
  });
  @override
  State<RosemaryAnchoredOverlay> createState() => _AnchoredOverlayState();
}

class _AnchoredOverlayState extends State<RosemaryAnchoredOverlay> {
  bool up = false;
  @override
  Widget build(BuildContext context) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final box = widget.anchor.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero, ancestor: overlay)
        : Offset.zero;
    final rect = origin & (box?.size ?? Size.zero);
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _RosemaryPopupLayout(
          rect,
          Directionality.of(context),
          joined: widget.joined,
          onDirection: (value) {
            if (value != up)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && up != value) {
                  setState(() => up = value);
                  widget.onDirectionChanged?.call(value);
                }
              });
          },
        ),
        child: widget.reveal == null
            ? widget.child
            : AnimatedBuilder(
                animation: widget.reveal!,
                builder: (context, child) => ClipRect(
                  clipper: _RosemaryRevealClipper(widget.reveal!.value, up),
                  child: child,
                ),
                child: widget.child,
              ),
      ),
    );
  }
}

class _RosemaryPopupLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final TextDirection direction;
  final bool joined;
  final ValueChanged<bool> onDirection;
  const _RosemaryPopupLayout(
    this.anchor,
    this.direction, {
    this.joined = false,
    required this.onDirection,
  });
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final below = (constraints.maxHeight - anchor.bottom - 12).clamp(
      0.0,
      constraints.maxHeight,
    );
    final above = (anchor.top - 12).clamp(0.0, constraints.maxHeight);
    return BoxConstraints(
      minWidth: joined ? anchor.width.clamp(0.0, constraints.maxWidth - 16) : 0,
      maxWidth: joined
          ? anchor.width.clamp(0.0, constraints.maxWidth - 16)
          : (constraints.maxWidth - 16).clamp(0.0, constraints.maxWidth),
      maxHeight: below > above ? below : above,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = size.height - anchor.bottom - 12;
    final above = anchor.top - 12;
    final flipped = !(childSize.height <= below || below >= above);
    onDirection(flipped);
    final y = !flipped
        ? anchor.bottom + (joined ? 0 : 4)
        : anchor.top - childSize.height - (joined ? 0 : 4);
    final x = direction == TextDirection.rtl
        ? anchor.right - childSize.width
        : anchor.left;
    return Offset(
      x.clamp(8.0, (size.width - childSize.width - 8).clamp(8.0, size.width)),
      y.clamp(
        8.0,
        (size.height - childSize.height - 8).clamp(8.0, size.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_RosemaryPopupLayout old) =>
      anchor != old.anchor ||
      direction != old.direction ||
      joined != old.joined;
}

class RosemaryDialog extends StatefulWidget {
  final bool open;
  final String title;
  final Widget child;
  final ValueChanged<RosemaryDismissReason> onDismiss;
  final VoidCallback? onAnimationFinished;
  final bool modal;
  final EdgeInsetsGeometry padding;
  const RosemaryDialog({
    super.key,
    required this.open,
    required this.title,
    required this.child,
    required this.onDismiss,
    this.onAnimationFinished,
    this.modal = true,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  State<RosemaryDialog> createState() => _PanelState();
}

class RosemaryDrawer extends RosemaryDialog {
  final double width;
  const RosemaryDrawer({
    super.key,
    required super.open,
    required super.title,
    required super.child,
    required super.onDismiss,
    super.onAnimationFinished,
    super.modal = true,
    this.width = 420,
  });
}

class _PanelState extends State<RosemaryDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  FocusNode? previous;
  OverlayEntry? entry;
  RosemaryOverlaySnapshot? captured;
  bool dismissRequested = false;
  Animation<double>? routeAnimation;
  void routeSettled(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && widget.open)
      scope.requestFocus();
  }

  bool get drawer => widget is RosemaryDrawer;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !widget.open) {
        _remove();
        widget.onAnimationFinished?.call();
      } else if (status == AnimationStatus.completed) {
        widget.onAnimationFinished?.call();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (routeAnimation != animation) {
      routeAnimation?.removeStatusListener(routeSettled);
      routeAnimation = animation;
      routeAnimation?.addStatusListener(routeSettled);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(RosemaryDialog old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) dismissRequested = false;
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scope.traversalEdgeBehavior = widget.modal
          ? TraversalEdgeBehavior.closedLoop
          : TraversalEdgeBehavior.parentScope;
      captured = RosemaryOverlaySnapshot.capture(
        context,
        Overlay.of(context).context,
      );
      controller.duration = rosemaryDuration(
        context,
        drawer ? 'drawerEnterMs' : 'transition',
      );
      controller.reverseDuration = rosemaryDuration(
        context,
        drawer ? 'drawerExitMs' : 'exit',
      );
      if (widget.open) {
        if (entry == null) {
          previous = FocusManager.instance.primaryFocus;
          entry = OverlayEntry(builder: _buildOverlay);
          Overlay.of(context).insert(entry!);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.open) scope.requestFocus();
          });
        }
        controller.forward();
      } else if (entry != null) {
        controller.reverse();
      }
      entry?.markNeedsBuild();
    });
  }

  void _dismiss(RosemaryDismissReason reason) {
    if (!widget.open || dismissRequested) return;
    dismissRequested = true;
    widget.onDismiss(reason);
    // Deduplicate one dispatch, but a controlled host may refuse to close.
    scheduleMicrotask(() => dismissRequested = false);
  }

  void _remove() {
    entry?.remove();
    entry?.dispose();
    entry = null;
    if (previous?.context != null) previous!.requestFocus();
    previous = null;
  }

  Widget _buildOverlay(BuildContext overlayContext) => captured!.wrap(
    AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = RosemaryThemeData.of(context),
            rtl = Directionality.of(context) == TextDirection.rtl;
        final size = MediaQuery.sizeOf(context);
        final width = drawer
            ? (widget as RosemaryDrawer).width.clamp(0.0, size.width * .9)
            : size.width.clamp(0.0, 560.0);
        final fraction = c.reduceMotion
            ? (widget.open ? 1.0 : 0.0)
            : controller.value;
        final panel = Material(
          type: MaterialType.transparency,
          child: Container(
            width: width,
            constraints: BoxConstraints(maxHeight: size.height),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: c.surfaceFloating,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              borderRadius: drawer
                  ? const BorderRadiusDirectional.only(
                      topStart: Radius.circular(RosemaryTokens.dialogRadius),
                      bottomStart: Radius.circular(RosemaryTokens.dialogRadius),
                    )
                  : BorderRadius.circular(RosemaryTokens.dialogRadius),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: drawer ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      namesRoute: true,
                      child: RosemaryText(widget.title, role: 'heading'),
                    ),
                    const SizedBox(height: 16),
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        );
        final content = FocusScope(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              _dismiss(RosemaryDismissReason.escape);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          node: scope,
          autofocus: true,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _dismiss(RosemaryDismissReason.escape);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Semantics(
              scopesRoute: widget.modal,
              explicitChildNodes: true,
              child: Stack(
                children: [
                  if (widget.modal)
                    Positioned.fill(
                      child: Semantics(
                        label: rString(context, 'Close'),
                        onTap: () => _dismiss(RosemaryDismissReason.outside),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _dismiss(RosemaryDismissReason.outside),
                          child: ColoredBox(
                            color: Colors.black.withValues(
                              alpha: .32 * fraction,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (drawer)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Transform.translate(
                        offset: Offset(
                          (rtl ? -1 : 1) * width * (1 - fraction),
                          0,
                        ),
                        child: SizedBox(height: size.height, child: panel),
                      ),
                    )
                  else
                    Center(
                      child: Opacity(
                        opacity: fraction,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - fraction)),
                          child: panel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        return widget.modal ? BlockSemantics(child: content) : content;
      },
    ),
  );
  @override
  void dispose() {
    routeAnimation?.removeStatusListener(routeSettled);
    controller.dispose();
    _remove();
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.open,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && widget.open) _dismiss(RosemaryDismissReason.back);
    },
    child: const SizedBox.shrink(),
  );
}

class RosemaryPopover extends StatefulWidget {
  final bool open;
  final Widget trigger, child;
  final ValueChanged<RosemaryDismissReason> onDismiss;
  final ValueChanged<bool>? onOpenChanged;
  const RosemaryPopover({
    super.key,
    required this.open,
    required this.trigger,
    required this.child,
    required this.onDismiss,
    this.onOpenChanged,
  });
  @override
  State<RosemaryPopover> createState() => _PopoverState();
}

class _PopoverState extends State<RosemaryPopover> {
  final anchor = GlobalKey();
  OverlayEntry? entry;
  FocusNode? previous;
  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.open && entry == null) {
        previous = FocusManager.instance.primaryFocus;
        entry = OverlayEntry(
          builder: (overlayContext) =>
              RosemaryOverlaySnapshot.capture(
                context,
                Overlay.of(context).context,
              ).wrap(
                Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            widget.onDismiss(RosemaryDismissReason.outside),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    RosemaryAnchoredOverlay(
                      anchor: anchor,
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.escape) {
                            widget.onDismiss(RosemaryDismissReason.escape);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Material(
                          type: MaterialType.transparency,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 24,
                              maxHeight: MediaQuery.sizeOf(context).height * .7,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: RosemaryThemeData.of(
                                context,
                              ).surfaceFloating,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(
                                RosemaryTokens.contentRadius,
                              ),
                              border: Border.all(
                                color: RosemaryThemeData.of(context).edgeSoft,
                              ),
                            ),
                            child: SingleChildScrollView(child: widget.child),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        );
        Overlay.of(context).insert(entry!);
        widget.onOpenChanged?.call(true);
      } else if (!widget.open && entry != null) {
        _remove();
        widget.onOpenChanged?.call(false);
      } else {
        entry?.markNeedsBuild();
      }
    });
  }

  void _remove() {
    entry?.remove();
    entry?.dispose();
    entry = null;
    if (previous?.context != null) previous!.requestFocus();
    previous = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RosemaryPopover old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: anchor, child: widget.trigger);
}

class RosemaryTooltip extends StatefulWidget {
  final String message;
  final Widget child;
  final ValueChanged<bool>? onOpenChanged;
  const RosemaryTooltip({
    super.key,
    required this.message,
    required this.child,
    this.onOpenChanged,
  });
  @override
  State<RosemaryTooltip> createState() => _TooltipState();
}

class _TooltipState extends State<RosemaryTooltip> {
  bool open = false;
  void change(bool value) {
    if (value != open) {
      setState(() => open = value);
      widget.onOpenChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: change,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        change(false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: MouseRegion(
      onEnter: (_) => change(true),
      onExit: (_) => change(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.child,
          if (open)
            Semantics(
              label: widget.message,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RosemaryThemeData.of(context).surfaceFloating,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: RosemaryThemeData.of(context).edgeSoft,
                  ),
                  borderRadius: BorderRadius.circular(
                    RosemaryTokens.controlRadius,
                  ),
                ),
                child: RosemaryText(widget.message, role: 'small'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _RosemaryRevealClipper extends CustomClipper<Rect> {
  final double progress;
  final bool up;
  _RosemaryRevealClipper(this.progress, this.up);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    up ? size.height * (1 - progress) : 0,
    size.width,
    size.height * progress,
  );
  @override
  bool shouldReclip(_RosemaryRevealClipper old) =>
      old.progress != progress || old.up != up;
}
