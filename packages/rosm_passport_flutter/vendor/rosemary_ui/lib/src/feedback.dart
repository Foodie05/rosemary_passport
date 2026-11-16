import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'primitives.dart';
import 'generated/rosemary_tokens.dart';

enum RosemaryLoadingState {
  idle,
  running,
  completed,
  error,
  cancelled,
  timeout,
}

class RosemaryLoading extends StatefulWidget {
  final double size;
  final Color? color;
  final String label;
  final RosemaryLoadingState state;
  final VoidCallback? onCancel;
  final Duration? appearanceDelay;
  const RosemaryLoading({
    super.key,
    this.size = 32,
    this.color,
    this.label = 'Loading',
    this.state = RosemaryLoadingState.running,
    this.onCancel,
    this.appearanceDelay,
  });
  @override
  State<RosemaryLoading> createState() => _LoadingState();
}

class _LoadingState extends State<RosemaryLoading>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController controller;
  bool active = true;
  late bool visible;
  Timer? appearanceTimer;
  @override
  void initState() {
    super.initState();
    visible = widget.state != RosemaryLoadingState.running;
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: rosemaryMotion('loadingCycleMs')),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    if (widget.state == RosemaryLoadingState.running &&
        active &&
        !visible &&
        appearanceTimer == null) {
      appearanceTimer = Timer(
        widget.appearanceDelay ??
            Duration(
              milliseconds: RosemaryTokens
                  .componentTokens["loading"]!
                  .dimensions["appearanceDelayMs"]!
                  .toInt(),
            ),
        () {
          appearanceTimer = null;
          if (mounted &&
              widget.state == RosemaryLoadingState.running &&
              active) {
            setState(() => visible = true);
            _sync();
          }
        },
      );
    } else if (widget.state != RosemaryLoadingState.running || !active) {
      appearanceTimer?.cancel();
      appearanceTimer = null;
    }
    if (visible &&
        widget.state == RosemaryLoadingState.running &&
        active &&
        !RosemaryThemeData.of(context).reduceMotion &&
        TickerMode.valuesOf(context).enabled) {
      if (!controller.isAnimating) controller.repeat();
    } else {
      controller.stop();
      if (widget.state != RosemaryLoadingState.running ||
          RosemaryThemeData.of(context).reduceMotion)
        controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RosemaryLoading old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appearanceTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !visible
      ? SizedBox(width: widget.size, height: widget.size * 1.125)
      : Semantics(
          label: rString(context, widget.label),
          value: rString(context, switch (widget.state) {
            RosemaryLoadingState.running => 'In progress',
            RosemaryLoadingState.completed => 'Completed',
            RosemaryLoadingState.cancelled => 'Cancelled',
            RosemaryLoadingState.error => 'Error',
            RosemaryLoadingState.timeout => 'Timeout',
            _ => 'Loading',
          }),
          liveRegion: widget.state != RosemaryLoadingState.running,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: widget.size,
                  height: widget.size * 1.125,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => CustomPaint(
                      painter: _FoldPainter(
                        controller.value,
                        widget.color ?? RosemaryThemeData.of(context).primary,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.onCancel != null)
                RosemaryButton(
                  label: rString(context, 'Cancel'),
                  onPressed: widget.onCancel,
                  variant: RosemaryButtonVariant.text,
                ),
            ],
          ),
        );
}

class _FoldPainter extends CustomPainter {
  final double t;
  final Color color;
  _FoldPainter(this.t, this.color);
  double sequence(
    List<double> values, {
    List<double> stops = const [0.0, .2, .45, .7, 1.0],
  }) {
    for (var i = 0; i < values.length - 1; i++) {
      if (t <= stops[i + 1]) {
        final x = Curves.easeInOut.transform(
          (t - stops[i]) / (stops[i + 1] - stops[i]),
        );
        return values[i] + (values[i + 1] - values[i]) * x;
      }
    }
    return values.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    void facet(bool front) {
      final width = size.width * .38,
          height = size.height * .84,
          left = size.width * (front ? 0.39 : .24),
          top = size.height * .08;
      final pivot = front ? 0.0 : width;
      final degrees = sequence(front ? [0, 58, 0, -58, 0] : [0, -58, 0, 58, 0]);
      final angle = degrees * math.pi / 180;
      final opacity = sequence(
        front ? [1, .78, .92, 1] : [.4, .67, .51, .4],
        stops: const [0, .45, .7, 1],
      );
      final points = front
          ? [
              Offset(0, height * .15),
              Offset(width, 0),
              Offset(width, height * .85),
              Offset(0, height),
            ]
          : [
              Offset(0, 0),
              Offset(width, height * .15),
              Offset(width, height),
              Offset(0, height * .85),
            ];
      Offset project(Offset p) {
        final dx = p.dx - pivot;
        final z = -dx * math.sin(angle);
        final perspective = 3.75 * size.width;
        final scale = perspective / (perspective - z);
        return Offset(
          left + pivot + dx * math.cos(angle) * scale,
          top + height / 2 + (p.dy - height / 2) * scale,
        );
      }

      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = project(points[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
    }

    if (t >= .2 && t < .7) {
      facet(true);
      facet(false);
    } else {
      facet(false);
      facet(true);
    }
  }

  @override
  bool shouldRepaint(_FoldPainter old) => t != old.t || color != old.color;
}

enum RosemaryProgressState {
  idle,
  running,
  paused,
  cancelled,
  completed,
  error,
}

class RosemaryProgress extends StatefulWidget {
  final double? value;
  final double max;
  final String label;
  final VoidCallback? onCancel, onRetry;
  final bool paused;
  final RosemaryProgressState state;
  const RosemaryProgress({
    super.key,
    required this.value,
    this.max = 100,
    this.label = 'Progress',
    this.onCancel,
    this.onRetry,
    this.paused = false,
    this.state = RosemaryProgressState.running,
  });
  @override
  State<RosemaryProgress> createState() => _ProgressState();
}

class _ProgressState extends State<RosemaryProgress>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController flow;
  bool active = true;
  @override
  void initState() {
    super.initState();
    flow = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: rosemaryMotion('progressFlowMs')),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    if (active &&
        !widget.paused &&
        widget.state == RosemaryProgressState.running &&
        !RosemaryThemeData.of(context).reduceMotion &&
        (widget.value == null || widget.value! < widget.max) &&
        TickerMode.valuesOf(context).enabled) {
      if (!flow.isAnimating) flow.repeat();
    } else {
      flow.stop();
      flow.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RosemaryProgress old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.max.isFinite ||
        widget.max <= 0 ||
        widget.value != null && !widget.value!.isFinite)
      throw ArgumentError(
        'Progress requires finite value and positive finite max',
      );
    final fraction = widget.value == null
        ? null
        : (widget.value! / widget.max).clamp(0.0, 1.0);
    final c = RosemaryThemeData.of(context);
    return Semantics(
      label: widget.label,
      value:
          '${rString(context, switch (widget.state) {
            RosemaryProgressState.cancelled => 'Cancelled',
            RosemaryProgressState.error => 'Error',
            RosemaryProgressState.paused => 'Paused',
            RosemaryProgressState.completed => 'Completed',
            RosemaryProgressState.idle => 'Not started',
            _ => fraction == 1 ? 'Completed' : 'In progress',
          })}, ${fraction == null ? rString(context, 'Indeterminate') : '${(fraction * 100).round()}%'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RosemaryText(
            '${widget.label}: ${fraction == null ? rString(context, 'In progress') : '${(fraction * 100).round()}%'}',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction ?? 1),
              duration: rosemaryDuration(context, 'progressMs'),
              builder: (context, animated, _) => AnimatedBuilder(
                animation: flow,
                builder: (context, _) => SizedBox(
                  height: 12,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ProgressPainter(
                      animated,
                      flow.value,
                      c.primary,
                      c.control,
                      Directionality.of(context) == TextDirection.rtl,
                      !c.reduceMotion &&
                          !widget.paused &&
                          widget.state == RosemaryProgressState.running &&
                          active &&
                          (fraction == null || fraction < 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.onCancel != null || widget.onRetry != null)
            Wrap(
              children: [
                if (widget.onCancel != null)
                  RosemaryButton(
                    label: rString(context, 'Cancel'),
                    onPressed: widget.onCancel,
                    variant: RosemaryButtonVariant.text,
                  ),
                if (widget.onRetry != null)
                  RosemaryButton(
                    label: rString(context, 'Retry'),
                    onPressed: widget.onRetry,
                    variant: RosemaryButtonVariant.text,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double fraction, phase;
  final Color fill, track;
  final bool rtl, animate;
  _ProgressPainter(
    this.fraction,
    this.phase,
    this.fill,
    this.track,
    this.rtl,
    this.animate,
  );
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final width = size.width * fraction;
    final rect = Rect.fromLTWH(
      rtl ? size.width - width : 0,
      0,
      width,
      size.height,
    );
    canvas.drawRect(rect, Paint()..color = fill);
    if (animate) {
      canvas.save();
      canvas.clipRect(rect);
      final x = (phase * 1.6 - .3) * size.width;
      final highlight = Rect.fromLTWH(
        rtl ? size.width - x : x,
        0,
        size.width * .25,
        size.height,
      );
      canvas.drawRect(
        highlight,
        Paint()
          ..shader = LinearGradient(
            colors: [
              fill.withValues(alpha: 0),
              Colors.white.withValues(alpha: .22),
              fill.withValues(alpha: 0),
            ],
          ).createShader(highlight),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => true;
}

class RosemarySkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final String label;
  const RosemarySkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.label = 'Loading',
  });
  @override
  State<RosemarySkeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<RosemarySkeleton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController pulse;
  bool active = true;
  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: rosemaryMotion('skeletonCycleMs')),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void sync() {
    if (active &&
        !RosemaryThemeData.of(context).reduceMotion &&
        TickerMode.valuesOf(context).enabled) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      pulse.stop();
      pulse.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: rString(context, widget.label),
    child: AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => Opacity(
        opacity: RosemaryThemeData.of(context).reduceMotion
            ? 1
            : .55 + .45 * pulse.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: RosemaryThemeData.of(context).border,
            borderRadius: BorderRadius.circular(RosemaryTokens.controlRadius),
          ),
        ),
      ),
    ),
  );
}

class RosemaryBadge extends StatelessWidget {
  final String label;
  final RosemaryTone tone;
  const RosemaryBadge(
    this.label, {
    super.key,
    this.tone = RosemaryTone.neutral,
  });
  @override
  Widget build(BuildContext context) {
    final colors = rosemaryToneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(99),
      ),
      child: RosemaryText(label, role: 'small', color: colors.$2),
    );
  }
}

(Color, Color) rosemaryToneColors(BuildContext context, RosemaryTone tone) {
  final c = RosemaryThemeData.of(context);
  return switch (tone) {
    RosemaryTone.info => (c.infoSoft, c.info),
    RosemaryTone.success => (c.successSoft, c.success),
    RosemaryTone.warning => (c.warningSoft, c.warning),
    RosemaryTone.danger => (c.dangerSoft, c.danger),
    _ => (c.primarySoft, c.ink),
  };
}

class RosemaryAlert extends StatelessWidget {
  final String message;
  final RosemaryTone tone;
  final Widget? action;
  const RosemaryAlert(
    this.message, {
    super.key,
    this.tone = RosemaryTone.info,
    this.action,
  });
  @override
  Widget build(BuildContext context) {
    final colors = rosemaryToneColors(context, tone);
    return Semantics(
      liveRegion: tone == RosemaryTone.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.circular(RosemaryTokens.contentRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RosemaryText(message, color: colors.$2),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class RosemaryEmpty extends StatelessWidget {
  final String title, description;
  final Widget? action;
  const RosemaryEmpty({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(header: true, child: RosemaryText(title, role: 'heading')),
      RosemaryText(description),
      if (action != null) action!,
    ],
  );
}

class RosemaryAvatar extends StatelessWidget {
  final String label;
  final ImageProvider? image;
  final double size;
  const RosemaryAvatar({
    super.key,
    required this.label,
    this.image,
    this.size = 48,
  });
  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join();
    final fallback = Center(child: RosemaryText(initials));
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: ClipOval(
          child: Container(
            width: size,
            height: size,
            color: RosemaryThemeData.of(context).primarySoft,
            child: image == null
                ? fallback
                : Image(
                    image: image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

class RosemaryToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? timeout;
  final bool paused;
  const RosemaryToast({
    super.key,
    required this.message,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
    this.timeout,
    this.paused = false,
  });
  @override
  State<RosemaryToast> createState() => _ToastState();
}

class _ToastState extends State<RosemaryToast> with WidgetsBindingObserver {
  Timer? timer;
  Stopwatch elapsed = Stopwatch();
  Duration? remaining;
  bool hover = false, focus = false, active = true;
  @override
  void initState() {
    super.initState();
    remaining = widget.timeout;
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  void _sync() {
    if (timer != null) {
      remaining = remaining! - elapsed.elapsed;
      timer!.cancel();
      timer = null;
      elapsed.reset();
    }
    if (remaining != null && !widget.paused && !hover && !focus && active) {
      elapsed.start();
      timer = Timer(
        remaining! < Duration.zero ? Duration.zero : remaining!,
        () {
          timer = null;
          remaining = null;
          if (mounted) widget.onDismiss();
        },
      );
    } else {
      elapsed.stop();
    }
  }

  @override
  void didUpdateWidget(RosemaryToast old) {
    super.didUpdateWidget(old);
    if (old.timeout != widget.timeout || old.message != widget.message) {
      timer?.cancel();
      timer = null;
      elapsed.reset();
      remaining = widget.timeout;
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (v) {
      focus = v;
      _sync();
    },
    child: MouseRegion(
      onEnter: (_) {
        hover = true;
        _sync();
      },
      onExit: (_) {
        hover = false;
        _sync();
      },
      child: Semantics(
        liveRegion: true,
        child: RosemaryAlert(
          widget.message,
          tone: RosemaryTone.neutral,
          action: Wrap(
            children: [
              if (widget.actionLabel != null && widget.onAction != null)
                RosemaryButton(
                  label: widget.actionLabel!,
                  onPressed: widget.onAction,
                  variant: RosemaryButtonVariant.text,
                ),
              RosemaryButton(
                label: rString(context, 'Close'),
                onPressed: widget.onDismiss,
                variant: RosemaryButtonVariant.text,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
