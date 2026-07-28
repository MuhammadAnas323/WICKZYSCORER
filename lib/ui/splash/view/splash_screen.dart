import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/ui/splash/viewmodel/splash_viewmodel.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _fadeController;

  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _particleOpacity;
  late Animation<double> _fadeAnim;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _rotateAnim = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.easeInOut,
      ),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _particleOpacity = Tween<double>(begin: 0.05, end: 0.2).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SplashState>(splashViewModelProvider, (prev, next) {
      if (!_navigated && !next.isLoading) {
        _navigated = true;
        context.go('/home');
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? AppColors.splashGradientDark
        : AppColors.splashGradientLight;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Stack(
            children: [
              ..._buildParticles(),
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: RotationTransition(
                      turns: _rotateAnim,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(
                              'assets/images/splash.png',
                              width: 340,
                              height: 600,
                              fit: BoxFit.cover,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _shimmerAnim,
                            builder: (_, __) => Container(
                              width: 340,
                              height: 600,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                  stops: [
                                    _shimmerAnim.value - 0.3,
                                    _shimmerAnim.value - 0.15,
                                    _shimmerAnim.value,
                                    _shimmerAnim.value + 0.15,
                                    _shimmerAnim.value + 0.3,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }

  List<Widget> _buildParticles() {
    final positions = <Offset>[
      const Offset(20, 60),
      const Offset(350, 40),
      const Offset(40, 400),
      const Offset(340, 360),
      const Offset(140, 140),
      const Offset(280, 520),
    ];
    return List.generate(6, (i) {
      final size = 30.0 + (i * 12);
      return Positioned(
        left: positions[i].dx,
        top: positions[i].dy,
        child: AnimatedBuilder(
          animation: _particleOpacity,
          builder: (_, __) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.floodlightGold
                  .withOpacity(_particleOpacity.value * (i.isEven ? 1 : 0.6)),
            ),
          ),
        ),
      );
    });
  }
}
