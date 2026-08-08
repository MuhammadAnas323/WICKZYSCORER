import 'package:flutter/material.dart';

class GlassOverlay extends StatelessWidget {
  const GlassOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // NOTE: intentionally no BackdropFilter blur here. A full-screen blur over
    // content that repaints every frame (particles, rays, Ken Burns pan) forces
    // the GPU to re-blur the whole screen on every frame, which is the main
    // cause of the startup "Skipped N frames" jank. Over the near-solid dark
    // background the blur was barely visible, so only the gradient tint remains.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.3),
            const Color(0xFF003314).withOpacity(0.2), // Dark green tint
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
