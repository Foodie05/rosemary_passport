// Derived from pinned rosemary_ui 0.5.0 overlays.dart; MIT, see vendor license.
// Only panel bounds, safe/keyboard gutters and UI heading metrics differ.
// Lifecycle, theme snapshot, focus restoration/trapping and dismissal stay upstream.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

class RosmInsetDialog extends StatefulWidget {
  final bool open;
  final String title;
  final Widget child;
  final ValueChanged<RosemaryDismissReason> onDismiss;
  final VoidCallback? onAnimationFinished;
  final bool modal;
  final EdgeInsetsGeometry padding;
  const RosmInsetDialog({
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
  State<RosmInsetDialog> createState() => _PanelState();
}

class RosmInsetDrawer extends RosmInsetDialog {
  final double width;
  const RosmInsetDrawer({
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

class _PanelState extends State<RosmInsetDialog>
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

  bool get drawer => widget is RosmInsetDrawer;
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
  void didUpdateWidget(RosmInsetDialog old) {
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
        final media = MediaQuery.of(context);
        final size = media.size;
        final gutters = EdgeInsets.fromLTRB(
          20 + media.padding.left,
          24 + media.padding.top,
          20 + media.padding.right,
          24 +
              (media.viewInsets.bottom > media.padding.bottom
                  ? media.viewInsets.bottom
                  : media.padding.bottom),
        );
        final width = drawer
            ? (widget as RosmInsetDrawer).width.clamp(0.0, size.width * .9)
            : (size.width - gutters.horizontal).clamp(0.0, 520.0);
        final fraction = c.reduceMotion
            ? (widget.open ? 1.0 : 0.0)
            : controller.value;
        final panel = Material(
          type: MaterialType.transparency,
          child: Container(
            width: width,
            constraints: BoxConstraints(
              maxHeight: drawer
                  ? size.height
                  : ((size.height - gutters.vertical) * .9).clamp(0.0, 680.0),
            ),
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
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: drawer ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        widget.title,
                        style: rosemaryTextStyle(context, 'body').copyWith(
                          fontSize: 20,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                    Padding(
                      padding: gutters,
                      child: Center(
                        child: Opacity(
                          opacity: fraction,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - fraction)),
                            child: panel,
                          ),
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
