import 'dart:math' as math;
import 'package:flutter/material.dart';

class LightRayPainter extends CustomPainter {
  final double animation;

  const LightRayPainter({
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawRay(
      canvas,
      size,
      animation,
      width: size.width * 0.22,
      opacity: 0.16,
      blur: 40,
      angle: -12,
    );

    _drawRay(
      canvas,
      size,
      (animation + 0.35) % 1,
      width: size.width * 0.18,
      opacity: 0.12,
      blur: 55,
      angle: -18,
    );

    _drawRay(
      canvas,
      size,
      (animation + 0.70) % 1,
      width: size.width * 0.15,
      opacity: 0.08,
      blur: 70,
      angle: -25,
    );
  }

  void _drawRay(
      Canvas canvas,
      Size size,
      double value, {
        required double width,
        required double opacity,
        required double blur,
        required double angle,
      }) {
    final x = lerpDouble(-width, size.width + width, value)!;

    canvas.save();

    canvas.translate(x, size.height / 2);

    canvas.rotate(angle * math.pi / 180);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: size.height * 1.8,
    );

    final paint = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        blur,
      )
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.6),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(200),
      ),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LightRayPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

double? lerpDouble(num a, num b, double t) {
  return a + (b - a) * t;
}