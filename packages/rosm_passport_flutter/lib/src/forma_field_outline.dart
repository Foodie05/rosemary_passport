// Copyright (c) 2026 Rosemary contributors. MIT License: ../../vendor/rosemary_ui/LICENSE
// MIT-derived from the SHA-verified Rosemary SDK 0.5.0 field outline.
// The public input has no controller/autofill hooks. This narrow editor adapter
// preserves its geometry and interaction tokens without importing private APIs.
import 'package:flutter/widgets.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

/// Two fronts on each horizontal edge reveal one tightly inset perimeter.
class RosmFieldOutline extends StatefulWidget {
  final Widget child;
  final bool focused, invalid;
  const RosmFieldOutline({
    super.key,
    required this.child,
    required this.focused,
    required this.invalid,
  });
  @override
  State<RosmFieldOutline> createState() => _OutlineState();
}

class _OutlineState extends State<RosmFieldOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController progress = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: RosemaryInteraction.fieldEnterMs.toInt()),
    value: widget.focused ? 1 : 0,
  );
  double origin = .5;
  bool pointerPending = false;
  @override
  void didUpdateWidget(RosmFieldOutline old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) {
      if (!pointerPending) origin = .5;
      pointerPending = false;
      if (RosemaryThemeData.of(context).reduceMotion) {
        progress.value = 1;
      } else {
        progress.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context),
        high = MediaQuery.highContrastOf(context),
        reduce = c.reduceMotion;
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        onPointerDown: (e) {
          if (!widget.focused) {
            origin = (e.localPosition.dx / constraints.maxWidth).clamp(0, 1);
            pointerPending = true;
          }
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.focused || widget.invalid || high ? 1 : 0),
          duration: Duration(
            milliseconds: reduce || widget.focused || widget.invalid
                ? 0
                : RosemaryInteraction.fieldExitMs.toInt(),
          ),
          builder: (context, opacity, child) => AnimatedBuilder(
            animation: progress,
            builder: (context, child) => CustomPaint(
              foregroundPainter: _EdgePainter(
                origin,
                widget.invalid || high || reduce
                    ? 1
                    : const Cubic(.2, .7, .2, 1).transform(progress.value),
                (widget.invalid
                        ? c.danger
                        : widget.focused
                        ? c.focus
                        : c.control)
                    .withValues(alpha: opacity),
                opacity > 0,
              ),
              child: child,
            ),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  final double origin, progress;
  final Color color;
  final bool visible;
  _EdgePainter(this.origin, this.progress, this.color, this.visible);
  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final w = (size.width - 1.5).clamp(0.0, double.infinity),
        h = (size.height - 1.5).clamp(0.0, double.infinity),
        r = (RosemaryTokens.controlRadius - .75).clamp(
          0.0,
          (w < h ? w : h) / 2,
        ),
        x = (origin * size.width - .75).clamp(r, w - r);
    final paths = <Path>[
      Path()
        ..moveTo(x, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, h - r)
        ..quadraticBezierTo(w, h, w - r, h)
        ..lineTo(x, h),
      Path()
        ..moveTo(x, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, r)
        ..quadraticBezierTo(w, 0, w - r, 0)
        ..lineTo(x, 0),
      Path()
        ..moveTo(x, 0)
        ..lineTo(r, 0)
        ..quadraticBezierTo(0, 0, 0, r)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(x, h),
      Path()
        ..moveTo(x, h)
        ..lineTo(r, h)
        ..quadraticBezierTo(0, h, 0, h - r)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(x, 0),
    ];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = RosemaryInteraction.fieldWidth;
    canvas.save();
    canvas.translate(.75, .75);
    for (final path in paths) {
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * .501 * progress),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.origin != origin ||
      old.progress != progress ||
      old.color != color ||
      old.visible != visible;
}
