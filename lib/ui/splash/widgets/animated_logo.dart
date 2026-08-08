import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand logo shown directly on the splash (no boxy tile). It spins fast on
/// entry and decelerates to a stop at the end of the 5s master timeline.
class AnimatedLogo extends StatefulWidget {
  final AnimationController masterController;

  const AnimatedLogo({super.key, required this.masterController});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  static const double _logoSize = 140;
  static const String _logoAsset = 'assets/images/Crixora.png';

  // Fast spin (6 full turns) driven by the 5s master timeline, easing out so
  // the logo spins quickly then settles and stops at exactly 5s.
  late final Animation<double> _rotationAnimation;

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

    _rotationAnimation =
        Tween<double>(begin: 0.0, end: 6 * 2 * math.pi).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: Curves.easeInOutCubic,
      ),
    );

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
                    // Direct logo — spinning fast, no boxy tile around it.
                    Transform.rotate(
                      angle: _rotationAnimation.value,
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
