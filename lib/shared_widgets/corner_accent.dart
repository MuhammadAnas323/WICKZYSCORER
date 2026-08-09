import 'package:flutter/material.dart';

/// A decorative colored corner used on cards that live on a neutral surface.
///
/// Instead of painting the whole card with a gradient, only a small rounded
/// corner is filled so the card stays clean while keeping a pop of color that
/// is unique per match / tournament (via [gradient]).
class CornerAccent extends StatelessWidget {
  final Gradient gradient;
  final double size;

  const CornerAccent({
    super.key,
    required this.gradient,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(48),
            ),
          ),
        ),
      ),
    );
  }
}
