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
    
    // The Flutter splash master timeline is exactly 4.0 seconds. The window is
    // plain white while the Flutter engine starts, then this splash takes over
    // on the first frame. The logo's continuous rotation runs on its own
    // repeating controller (see AnimatedLogo) and never decelerates or stops.
    // The ViewModel navigates away at exactly 4s, when the master timeline
    // completes.
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      // Matches the (removed) native splash background so the handoff from the
      // white engine-start window to Flutter's first frame is seamless.
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
