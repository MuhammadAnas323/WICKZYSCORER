import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/onboarding/viewmodel/onboarding_viewmodel.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';

import 'package:sportyapp/core/localization/app_localizations.dart';

class _OnboardingSlide {
  final String emoji;
  final String titleKey;
  final String subtitleKey;
  final List<Color> gradient;
  const _OnboardingSlide({
    required this.emoji,
    required this.titleKey,
    required this.subtitleKey,
    required this.gradient,
  });
}

const _slides = [
  _OnboardingSlide(
    emoji: '🏑',
    titleKey: 'onboarding_title_1',
    subtitleKey: 'onboarding_sub_1',
    gradient: [Color(0xFF0D2818), Color(0xFF1A7A3E)],
  ),
  _OnboardingSlide(
    emoji: '🏆',
    titleKey: 'onboarding_title_2',
    subtitleKey: 'onboarding_sub_2',
    gradient: [Color(0xFF1B2838), Color(0xFF2C4A6E)],
  ),
  _OnboardingSlide(
    emoji: '📡',
    titleKey: 'onboarding_title_3',
    subtitleKey: 'onboarding_sub_3',
    gradient: [Color(0xFF2D1B00), Color(0xFF8B5E3C)],
  ),
  _OnboardingSlide(
    emoji: '👥',
    titleKey: 'onboarding_title_4',
    subtitleKey: 'onboarding_sub_4',
    gradient: [Color(0xFF1A0A2E), Color(0xFF4A148C)],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    final vm = ref.read(onboardingViewModelProvider.notifier);
    final current = ref.read(onboardingViewModelProvider).currentPage;
    if (current < _slides.length - 1) {
      vm.nextPage();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        context.go(user.isScorer ? '/scorer/dashboard' : '/home');
      } else {
        context.go('/role-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingViewModelProvider);
    final l10n = AppLocalizations.of(context);
    final isLast = state.currentPage == _slides.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Page view of slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) {
              ref.read(onboardingViewModelProvider.notifier).setPage(i);
            },
            itemCount: _slides.length,
            itemBuilder: (context, i) => _OnboardingPage(slide: _slides[i]),
          ),

          // Skip button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: TextButton(
              onPressed: () {
                final user = ref.read(currentUserProvider);
                if (user != null) {
                  context.go(user.isScorer ? '/scorer/dashboard' : '/home');
                } else {
                  context.go('/role-selection');
                }
              },
              child: Text(
                l10n.translate('skip'),
                style: AppTextStyles.labelLarge(Colors.white70),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24, right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page dots
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _slides.length,
                  effect: const WormEffect(
                    activeDotColor: AppColors.floodlightGold,
                    dotColor: Colors.white38,
                    dotHeight: 8, dotWidth: 8,
                    spacing: 8,
                  ),
                ),
                const SizedBox(height: 32),
                // Next / Get Started button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.floodlightGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _next,
                    child: Text(
                      isLast ? l10n.translate('get_started') : l10n.translate('next'),
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingSlide slide;
  const _OnboardingPage({required this.slide});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: slide.gradient,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              // Large emoji
              Center(
                child: Text(slide.emoji,
                  style: const TextStyle(fontSize: 100)),
              ),
              const Spacer(),
              // Title
              Text(l10n.translate(slide.titleKey),
                style: GoogleFonts.poppins(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1.2)),
              const SizedBox(height: 16),
              // Subtitle
              Text(l10n.translate(slide.subtitleKey),
                style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w400,
                  color: Colors.white70, height: 1.6)),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
