import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand logo shown directly on the splash (no boxy tile). The logo spins
/// continuously at a constant linear speed on its own dedicated repeating
/// controller — one full turn per [AnimatedLogo.spinDuration]. Rotation is
/// decoupled from the master entrance timeline, so it never eases out or stops.
class AnimatedLogo extends StatefulWidget {
  /// One full rotation, in milliseconds.
  static const Duration spinDuration = Duration(milliseconds: 1400);

  final AnimationController masterController;

  const AnimatedLogo({super.key, required this.masterController});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  static const double _logoSize = 140;
  static const String _logoAsset = 'assets/images/Crixora.png';

  // Continuous, constant-speed rotation — fully decoupled from the master
  // timeline so the logo keeps turning at the same rate throughout the splash.
  late final AnimationController _spinController;

  // Gentle vertical float, repeated indefinitely while the logo spins.
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  // Entrance choreography, driven by the master timeline.
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // One full 360° turn every 1400ms, linear, never stopping.
    _spinController = AnimationController(
      vsync: this,
      duration: AnimatedLogo.spinDuration,
    )..repeat();

    // Quick fade-in so the logo is already visible when the native splash hands
    // over to Flutter's first frame.
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: const Interval(0.0, 0.12, curve: Curves.easeOut),
      ),
    );

    // Settle-in scale: grows slightly, then eases back to rest (no snap).
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: const Interval(0.15, 0.5, curve: Curves.easeInOut),
      ),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.masterController,
          _floatController,
          _spinController,
        ]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glowing halo ring
                    Container(
                      width: _logoSize + 48,
                      height: _logoSize + 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF2ECC71)
                              .withValues(alpha: 0.55 * _glowAnimation.value),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2ECC71)
                                .withValues(alpha: 0.4 * _glowAnimation.value),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    // Direct logo — spinning continuously at a constant speed,
                    // no boxy tile around it.
                    Transform.rotate(
                      angle: _spinController.value * 2 * math.pi,
                      child: ClipOval(
                        child: Image.asset(
                          _logoAsset,
                          width: _logoSize,
                          height: _logoSize,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: _logoSize,
                            height: _logoSize,
                            color: const Color(0xFF0D2818),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.sports_cricket,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
