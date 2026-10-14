// Generated from epass-mark.json by scripts/sync_epass_tokens.py.
import 'package:flutter/material.dart';

void paintEpassBadge(Canvas canvas, Size size, Color primary, Color onPrimary) {
  canvas.save();
  canvas.scale(size.width / 64, size.height / 64);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 56, 56),
      const Radius.circular(14),
    ),
    Paint()..color = primary.withValues(alpha: 0.1),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 5, 54, 54),
      const Radius.circular(13),
    ),
    Paint()
      ..color = primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final p2 = Path()
    ..moveTo(18, 50)
    ..quadraticBezierTo(15, 50, 15, 47)
    ..lineTo(15, 31)
    ..cubicTo(15, 20.5, 22, 14, 32, 14)
    ..cubicTo(42, 14, 49, 20.5, 49, 31)
    ..lineTo(49, 47)
    ..quadraticBezierTo(49, 50, 46, 50)
    ..lineTo(41, 50)
    ..quadraticBezierTo(38, 50, 38, 47)
    ..lineTo(38, 32)
    ..cubicTo(38, 27.8, 35.9, 25, 32, 25)
    ..cubicTo(28.1, 25, 26, 27.8, 26, 32)
    ..lineTo(26, 47)
    ..quadraticBezierTo(26, 50, 23, 50)
    ..close();
  canvas.drawPath(p2, Paint()..color = primary.withValues(alpha: 0.14));
  final p3 = Path()
    ..moveTo(18, 48)
    ..quadraticBezierTo(15, 48, 15, 45)
    ..lineTo(15, 29)
    ..cubicTo(15, 18.5, 22, 12, 32, 12)
    ..cubicTo(42, 12, 49, 18.5, 49, 29)
    ..lineTo(49, 45)
    ..quadraticBezierTo(49, 48, 46, 48)
    ..lineTo(41, 48)
    ..quadraticBezierTo(38, 48, 38, 45)
    ..lineTo(38, 30)
    ..cubicTo(38, 25.8, 35.9, 23, 32, 23)
    ..cubicTo(28.1, 23, 26, 25.8, 26, 30)
    ..lineTo(26, 45)
    ..quadraticBezierTo(26, 48, 23, 48)
    ..close();
  canvas.drawPath(p3, Paint()..color = primary.withValues(alpha: 1));
  final p4 = Path()
    ..moveTo(32, 12)
    ..cubicTo(42, 12, 49, 18.5, 49, 29)
    ..lineTo(49, 45)
    ..quadraticBezierTo(49, 48, 46, 48)
    ..lineTo(44, 48)
    ..lineTo(44, 29)
    ..cubicTo(44, 20.5, 39.5, 14.5, 32, 12)
    ..close();
  canvas.drawPath(p4, Paint()..color = onPrimary.withValues(alpha: 0.18));
  canvas.restore();
}
