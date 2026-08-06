import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../custom_painters/particle_painter.dart';

class ParticleSystem extends StatefulWidget {
  const ParticleSystem({super.key});

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final math.Random _random = math.Random();

  List<Particle> _particles = [];

  static const int particleCount = 120;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;

      _particles = List.generate(
        particleCount,
            (_) {
          return Particle(
            position: Offset(
              _random.nextDouble() * size.width,
              _random.nextDouble() * size.height,
            ),
            radius: _random.nextDouble() * 2.5 + 1,
            speed: _random.nextDouble() * 1.5 + 0.5,
            seed: _random.nextDouble() * 100,
            color: _random.nextBool()
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFFFD54F),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(
                  particles: _particles,
                  animation: _controller.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}