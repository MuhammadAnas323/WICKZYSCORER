import 'dart:math' as math;
import 'package:flutter/material.dart';

class Particle {
  final Offset position;
  final double radius;
  final double speed;
  final double seed;
  final Color color;

  const Particle({
    required this.position,
    required this.radius,
    required this.speed,
    required this.seed,
    required this.color,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;

  const ParticlePainter({
    required this.particles,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      _drawParticle(canvas, size, particle);
    }
  }

  void _drawParticle(
      Canvas canvas,
      Size size,
      Particle particle,
      ) {
    final t = animation * 2 * math.pi;

    final dx =
        particle.position.dx +
            math.cos(t * particle.speed + particle.seed) * 25;

    final dy =
        particle.position.dy +
            math.sin(t * particle.speed * 0.8 + particle.seed) * 18;

    final x = dx % size.width;
    final y = dy % size.height;

    final opacity =
        0.25 +
            0.75 *
                ((math.sin(
                  t * particle.speed +
                      particle.seed,
                ) +
                    1) /
                    2);

    final radius =
        particle.radius *
            (0.85 +
                0.20 *
                    math.sin(
                      t +
                          particle.seed,
                    ));

    /// Glow
    final glowPaint = Paint()
      ..color = particle.color.withOpacity(opacity * 0.18)
      ..maskFilter =
      const MaskFilter.blur(
        BlurStyle.normal,
        16,
      );

    canvas.drawCircle(
      Offset(x, y),
      radius * 3,
      glowPaint,
    );

    /// Core
    final particlePaint = Paint()
      ..color =
      particle.color.withOpacity(opacity);

    canvas.drawCircle(
      Offset(x, y),
      radius,
      particlePaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}