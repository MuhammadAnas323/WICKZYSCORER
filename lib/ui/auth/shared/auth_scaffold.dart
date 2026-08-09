import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// Light-mode scaffold shared by the sign-in / sign-up / role screens.
///
/// Forces a light palette regardless of the app theme so the auth flow always
/// feels bright and welcoming, and staggers a fade + slide entrance for the
/// logo, heading and form card.
class AuthScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.35)),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.15, 0.55)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: const Interval(0.15, 0.55, curve: Curves.easeOut)));
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.85)),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: const Interval(0.35, 0.85, curve: Curves.easeOut)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0D2818), theme.scaffoldBackgroundColor]
                : [const Color(0xFFEAF6EE), theme.scaffoldBackgroundColor],
          ),
        ),
        child: Stack(
          children: [
            // Decorative blurred shapes (cricket-field vibe).
            Positioned(
              top: -60,
              right: -50,
              child: _blurCircle(AppColors.pitchGreen.withValues(alpha: isDark ? 0.08 : 0.12), 180),
            ),
            Positioned(
              top: 140,
              left: -70,
              child: _blurCircle(AppColors.floodlightGold.withValues(alpha: isDark ? 0.06 : 0.10), 140),
            ),
            Positioned(
              bottom: -50,
              right: -40,
              child: _blurCircle(AppColors.vibrantCyan.withValues(alpha: isDark ? 0.06 : 0.10), 160),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _logoFade,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: const _AuthLogo(),
                      ),
                    ),
                    const Gap(20),
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headlineLarge(cs.onBackground),
                            ),
                            const Gap(8),
                            Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(28),
                    FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: widget.children,
                          ),
                        ),
                      ),
                    ),
                    if (widget.footer != null) ...[
                      const Gap(24),
                      widget.footer!,
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.pitchGreen.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/Crixora.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.sports_cricket,
            size: 40,
            color: AppColors.pitchGreen,
          ),
        ),
      ),
    );
  }
}
