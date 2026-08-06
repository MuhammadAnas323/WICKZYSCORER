import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodel/splash_viewmodel.dart';

class SplashLoadingIndicator extends ConsumerWidget {
  final AnimationController masterController;

  const SplashLoadingIndicator({super.key, required this.masterController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splashState = ref.watch(splashViewModelProvider);
    
    final Animation<double> fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: masterController,
        curve: const Interval(2.5 / 3.0, 3.0 / 3.0, curve: Curves.easeIn),
      ),
    );

    return AnimatedBuilder(
      animation: masterController,
      builder: (context, child) {
        if (masterController.value < (2.5 / 3.0)) {
          return const SizedBox.shrink();
        }
        
        return Opacity(
          opacity: fadeAnimation.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: splashState == SplashState.loading || splashState == SplashState.complete ? 1.0 : 0.0,
                  ),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOutSine,
                  builder: (context, value, child) {
                    return Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00C853), // Emerald
                                    Color(0xFFFFD700), // Gold
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C853).withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Loading Match Engine...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
