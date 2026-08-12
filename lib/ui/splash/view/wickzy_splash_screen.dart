// lib/ui/splash/view/wickzy_splash_screen.dart
// Phase-2 branded splash for WICKZYSCORER.
//
// Features a high-impact rotating icon intro followed by a letter-by-letter
// name reveal. Everything transitions seamlessly into the main app.

import 'package:flutter/material.dart';

/// ---- WickzyScorer brand palette (navy / silver / electric blue only) ----
const Color kWickzyNavy =
    Color(0xFF0B1026); // matches the native Phase-1 splash
const Color kWickzySilver = Color(0xFFE3E9F2);
const Color kWickzySilverDeep = Color(0xFF8E99AC);
const Color kWickzyBlue = Color(0xFF2E86FF);
const Color kWickzyBlueLight = Color(0xFF3F9BFF);
const Color kWickzyArc = Color(0xFF58B3FF);

/// Lifts the Phase-2 splash over the whole app (including the router) so it
/// can hand off seamlessly from the native launch screen and exit smoothly
/// into whatever screen the auth redirect resolved.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_gone)
          _WickzySplashOverlay(
            onFinished: () {
              if (mounted) setState(() => _gone = true);
            },
          ),
      ],
    );
  }
}

class _WickzySplashOverlay extends StatefulWidget {
  const _WickzySplashOverlay({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_WickzySplashOverlay> createState() => _WickzySplashOverlayState();
}

class _WickzySplashOverlayState extends State<_WickzySplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final AnimationController _textController;
  
  late final Animation<double> _rotation;
  late final Animation<double> _scale;
  
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    
    // Icon animation: Fast spin + Landing bounce
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _rotation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 1.0),
      ),
    );

    // Text reveal animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _iconController.forward().whenComplete(() {
      if (mounted) {
        _textController.forward().whenComplete(() {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _fading = true);
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: AnimatedOpacity(
        opacity: _fading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeInOut,
        onEnd: () {
          if (_fading && mounted) widget.onFinished();
        },
        child: ColoredBox(
          color: kWickzyNavy,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = (constraints.maxWidth * 0.4).clamp(120.0, 200.0);
                final fontSize = (constraints.maxWidth * 0.064).clamp(20.0, 30.0);
                
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _scale,
                        child: RotationTransition(
                          turns: _rotation,
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: side,
                            height: side,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, _) => _WickzyNameReveal(
                          progress: _textController.value,
                          fontSize: fontSize,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "WickzyScorer" — letter-by-letter reveal.
// ---------------------------------------------------------------------------

class _WickzyNameReveal extends StatelessWidget {
  const _WickzyNameReveal({required this.progress, required this.fontSize});

  static const String name = 'WickzyScorer';

  final double progress;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [kWickzySilver, kWickzySilverDeep, kWickzyBlueLight],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcATop,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < name.length; i++)
            _SplashLetter(
              letter: name[i],
              progress: (progress - i * 0.05) / 0.5,
              fontSize: fontSize,
            ),
        ],
      ),
    );
  }
}

class _SplashLetter extends StatelessWidget {
  const _SplashLetter({
    required this.letter,
    required this.progress,
    required this.fontSize,
  });

  final String letter;
  final double progress;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(p);
    final shift = (1.0 - eased) * 12.0;

    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, shift),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: 1.2,
            color: kWickzySilver,
            shadows: [
              Shadow(
                  color: kWickzyBlue.withValues(alpha: 0.55), blurRadius: 14),
              Shadow(color: kWickzyArc.withValues(alpha: 0.35), blurRadius: 30),
            ],
          ),
        ),
      ),
    );
  }
}
