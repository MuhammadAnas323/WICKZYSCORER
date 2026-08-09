import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/animated_background.dart';
import '../widgets/particle_system.dart';
import '../widgets/light_rays.dart';
import '../widgets/glass_overlay.dart';
import '../widgets/animated_logo.dart';
import '../widgets/wordmark.dart';
import '../widgets/loading_indicator.dart';
import '../viewmodel/splash_viewmodel.dart';
import '../../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _masterController;

  @override
  void initState() {
    super.initState();
    
    // The master timeline is exactly 5.0 seconds: the logo spins fast and
    // decelerates to a stop at ~5s, then the ViewModel navigates away.
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // Start the timeline
    _masterController.forward();
  }

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to ViewModel state changes for navigation
    ref.listen<SplashState>(splashViewModelProvider, (previous, next) {
      if (next == SplashState.complete) {
        // Timeline should also be complete, navigate to the correct shell based
        // on the restored session's role.
        if (context.mounted) {
          final user = ref.read(currentUserProvider);
          if (user == null) {
            context.go('/role-selection');
          } else if (user.isScorer) {
            context.go('/scorer/dashboard');
          } else {
            context.go('/home');
          }
        }
      }
    });

    return Scaffold(
      // Matches the native splash background (@color/launch_background) so the
      // handoff from the Android splash to Flutter's first frame is seamless.
      backgroundColor: const Color(0xFF0D2818),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ken Burns Animated Background
          const AnimatedBackground(
            child: SizedBox.expand(),
          ),

          // 2. Glassmorphism overlay + vignette
          const GlassOverlay(),

          // 3. Volumetric Light Rays
          const LightRays(),

          // 4. Particle System
          const ParticleSystem(),

          // 5. Main Content: Logo, Wordmark, and Loading
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  AnimatedLogo(masterController: _masterController),
                  
                  const SizedBox(height: 40),
                  
                  Wordmark(masterController: _masterController),
                  
                  const Spacer(flex: 2),
                  
                  SplashLoadingIndicator(masterController: _masterController),
                  
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
