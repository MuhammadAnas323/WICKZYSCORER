import 'package:flutter/material.dart';

class Wordmark extends StatefulWidget {
  final AnimationController masterController;

  const Wordmark({super.key, required this.masterController});

  @override
  State<Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<Wordmark> {
  final String text = "CRIXORA";
  final String tagline = "Experience Cricket Like Never Before";

  late List<Animation<double>> _letterFadeAnimations;
  late List<Animation<Offset>> _letterSlideAnimations;
  late Animation<double> _shineAnimation;
  late Animation<double> _taglineFadeAnimation;

  @override
  void initState() {
    super.initState();

    _letterFadeAnimations = [];
    _letterSlideAnimations = [];

    // All choreography timings below are expressed as fractions of the master
    // timeline's total duration (seconds), so the whole sequence rescales
    // automatically if the splash duration ever changes. With the 4s master
    // these resolve to: letters type in ~1.4–2.0s, shine sweeps 2.0–2.3s,
    // tagline fades in 2.3–2.5s.
    final double totalSeconds =
        widget.masterController.duration!.inMilliseconds / 1000.0;

    // Staggered letter animations from 1.5s to 2.0s
    final double startTime = 1.5 / totalSeconds;
    final double duration = 0.5 / totalSeconds;
    final double step = duration / text.length;

    for (int i = 0; i < text.length; i++) {
      final double letterStart = startTime + (i * step);
      final double letterEnd = letterStart + (duration / 2);

      _letterFadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: widget.masterController,
            curve: Interval(
              letterStart.clamp(0.0, 1.0),
              letterEnd.clamp(0.0, 1.0),
              curve: Curves.easeIn,
            ),
          ),
        ),
      );

      _letterSlideAnimations.add(
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: widget.masterController,
            curve: Interval(
              letterStart.clamp(0.0, 1.0),
              letterEnd.clamp(0.0, 1.0),
              curve: Curves.easeOutBack,
            ),
          ),
        ),
      );
    }

    // Shine animation from 2.0s to 2.3s
    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: Interval(
          2.0 / totalSeconds,
          2.3 / totalSeconds,
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Tagline animation from 2.3s to 2.5s
    _taglineFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.masterController,
        curve: Interval(
          2.3 / totalSeconds,
          2.5 / totalSeconds,
          curve: Curves.easeIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.masterController,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(text.length, (index) {
                return Opacity(
                  opacity: _letterFadeAnimations[index].value,
                  child: SlideTransition(
                    position: _letterSlideAnimations[index],
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.white,
                            const Color(0xFFFFD700).withOpacity(0.8), // Gold shine
                            Colors.white,
                            Colors.white,
                          ],
                          stops: [
                            0.0,
                            _shineAnimation.value - 0.2,
                            _shineAnimation.value,
                            _shineAnimation.value + 0.2,
                            1.0,
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        text[index],
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: Colors.white,
                          fontFamily: 'Inter', // Assuming Inter is available
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: _taglineFadeAnimation.value,
              child: Text(
                tagline,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
