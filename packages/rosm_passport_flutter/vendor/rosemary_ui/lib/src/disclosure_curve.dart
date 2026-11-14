import 'package:flutter/animation.dart';
import 'interaction_tokens.dart';

/// The portal's actual 41-point CSS linear() curve, not a substitute Bézier.
class RosemaryDisclosureCurve extends Curve {
  final bool opening;
  const RosemaryDisclosureCurve(this.opening);
  @override
  double transformInternal(double t) {
    final points = opening
        ? RosemaryInteraction.disclosureEnter
        : RosemaryInteraction.disclosureExit;
    final position = t.clamp(0.0, 1.0) * (points.length - 1);
    final index = position.floor().clamp(0, points.length - 2);
    return points[index] +
        (points[index + 1] - points[index]) * (position - index);
  }
}
