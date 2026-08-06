import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedLogo extends StatefulWidget {
  final AnimationController masterController;

  const AnimatedLogo({super.key, required this.masterController});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  static const double _logoSize = 132;
  static const String _logoAsset = 'assets/images/Crixora.png';

  // Continuous, gentle rotation — starts on the very first Flutter frame so the
  // icon keeps "flowing" from the native splash (which shows the same artwork).
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;

  // Gentle vertical float, repeated indefinitely.
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  // Entrance choreography, driven by the 3s master timeline.
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
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
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeInOut),
      ),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
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
          _rotationController,
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
                      width: _logoSize + 44,
                      height: _logoSize + 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00C853)
                              .withOpacity(0.55 * _glowAnimation.value),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C853)
                                .withOpacity(0.4 * _glowAnimation.value),
                            blurRadius: 22,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    // Brand logo tile — the same artwork as the native splash.
                    Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Container(
                        width: _logoSize,
                        height: _logoSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          image: const DecorationImage(
                            image: AssetImage(_logoAsset),
                            fit: BoxFit.cover,
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
