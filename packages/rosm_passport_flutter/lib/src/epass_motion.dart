import 'package:flutter/material.dart';
import 'package:rosemary_reference/rosemary.dart';
import 'epass_tokens.dart';

/// Presents exactly one live form. Selection changes semantics and focus immediately.
class RosmEpassSelectionContent extends StatefulWidget {
  const RosmEpassSelectionContent({
    super.key,
    required this.value,
    required this.child,
    this.order = 0,
  });
  final Object value;
  final int order;
  final Widget child;
  @override
  State<RosmEpassSelectionContent> createState() => _SelectionContentState();
}

class _SelectionContentState extends State<RosmEpassSelectionContent>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: RosmEpassMotion.settle,
    value: 1,
  );
  double _startOpacity = 1;
  double _startOffset = 0;
  bool _reduced = false;
  double get _progress => RosmEpassMotion.standard.transform(_controller.value);
  double get _opacity => _startOpacity + (1 - _startOpacity) * _progress;
  double get _offset => _startOffset * (1 - _progress);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant RosmEpassSelectionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value || _reduced) return;
    final animating = _controller.isAnimating;
    final opacity = _opacity;
    final offset = _offset;
    _startOpacity = animating ? opacity : 0;
    _startOffset = animating
        ? offset
        : (widget.order < oldWidget.order ? -12 : 12);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.translate(
      offset: Offset(_offset, 0),
      child: Opacity(
        opacity: _opacity,
        alwaysIncludeSemantics: true,
        child: child,
      ),
    ),
  );
}

/// Official SDK progress honors native platform behavior and system preferences.
class RosmEpassProgress extends StatelessWidget {
  const RosmEpassProgress({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(color: color ?? Theme.of(context).colorScheme.primary),
    child: const RosemarySpinner(label: '处理中', size: 20),
  );
}
