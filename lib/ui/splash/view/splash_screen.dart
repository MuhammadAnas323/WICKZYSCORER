// lib/ui/splash/view/splash_screen.dart
// CRIXORA premium animated splash screen — a single full-bleed animated photo
// with a slow Ken Burns drift, dark gradient, wordmark reveal and progress bar.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/ui/splash/viewmodel/splash_viewmodel.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const String _photoAsset = 'assets/images/Crixora.png';
  static const String _wordmark = 'CRIXORA';

  late final AnimationController _photoController;
  late final AnimationController _textController;
  late final AnimationController _progressController;

  late final Animation<double> _photoZoom;
  late final Animation<Offset> _photoPan;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // One slow, continuous drift for the single photo.
    _photoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _photoZoom = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _photoController, curve: Curves.easeInOut),
    );

    _photoPan = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.06, -0.04),
    ).animate(
      CurvedAnimation(parent: _photoController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _photoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SplashState>(splashViewModelProvider, (prev, next) {
      if (!_navigated && !next.isLoading) {
        _navigated = true;
        final user = ref.read(currentUserProvider);
        if (user != null) {
          context.go(user.isScorer ? '/scorer/dashboard' : '/home');
        } else {
          context.go('/role-selection');
        }
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildAnimatedPhoto(),
          _buildScrim(),
          _buildCenterContent(),
          _buildProgressBar(),
        ],
      ),
    );
  }

  // ── The single animated photo ──────────────────────────────────────────
  Widget _buildAnimatedPhoto() {
    return AnimatedBuilder(
      animation: _photoController,
      builder: (context, _) {
        return FractionalTranslation(
          translation: _photoPan.value,
          child: Transform.scale(
            scale: _photoZoom.value,
            child: Image.asset(
              _photoAsset,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _photoFallback(),
            ),
          ),
        );
      },
    );
  }

  Widget _photoFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A7A3E), Color(0xFF0D2818)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.sports_cricket, color: Colors.white, size: 96),
      ),
    );
  }

  // ── Dark gradient scrim for legibility ─────────────────────────────────
  Widget _buildScrim() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
          colors: [
            Color(0x66000000),
            Color(0x33000000),
            Color(0xCC0A0A0A),
          ],
        ),
      ),
    );
  }

  // ── Center: wordmark + tagline over the photo ──────────────────────────
  Widget _buildCenterContent() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildWordmark(),
          const SizedBox(height: 12),
          _buildTagline(),
        ],
      ),
    );
  }

  Widget _buildWordmark() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.floodlightGoldLight],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _wordmark.length; i++)
                _AnimatedLetter(
                  controller: _textController,
                  index: i,
                  letter: _wordmark[i],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, _) {
        final t = ((_textController.value - 0.55) / 0.45).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: Text(
              'LIVE CRICKET · EVERY BALL',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 3.5,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom loading bar ─────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 56),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, _) {
              return Container(
                width: 140,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _progressController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.pitchGreenLight,
                          AppColors.floodlightGoldLight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.floodlightGold.withOpacity(0.7),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Letter-by-letter wordmark reveal ─────────────────────────────────────
class _AnimatedLetter extends StatefulWidget {
  final String letter;
  final Animation<double> controller;
  final int index;

  const _AnimatedLetter({
    required this.letter,
    required this.controller,
    required this.index,
  });

  @override
  State<_AnimatedLetter> createState() => _AnimatedLetterState();
}

class _AnimatedLetterState extends State<_AnimatedLetter> {
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _anim = _buildAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedLetter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.index != widget.index) {
      _anim = _buildAnimation();
    }
  }

  Animation<double> _buildAnimation() {
    final start = widget.index * 0.07;
    return CurvedAnimation(
      parent: widget.controller,
      curve: Interval(
        start,
        math.min(start + 0.75, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - v)),
            child: Transform.rotate(
              angle: (1 - v) * 0.25,
              child: Text(
                widget.letter,
                style: GoogleFonts.poppins(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
