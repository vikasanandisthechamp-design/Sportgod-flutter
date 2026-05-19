import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// In-app splash screen shown during async initialization.
///
/// After a short delay it reads the onboarding flag and navigates to either
/// the home screen (`/`) or the onboarding flow (`/onboarding`).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;
    context.go(onboardingDone ? '/' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(flex: 3),

            // ── Logo ──────────────────────────────────────────────
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5A8), Color(0xFF00C9FF)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text(
                  'SG',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F0F11),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 500.ms,
                  curve: Curves.easeOut,
                ),

            const SizedBox(height: 28),

            // ── App name ──────────────────────────────────────────
            const Text(
              'SportGod AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms, curve: Curves.easeOut),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────────────
            const Text(
              'Super Scoreboard',
              style: TextStyle(
                fontSize: 13,
                color: SGColors.textMuted,
              ),
            )
                .animate(delay: 350.ms)
                .fadeIn(duration: 400.ms, curve: Curves.easeOut),

            const Spacer(flex: 3),

            // ── Loading indicator ─────────────────────────────────
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E5A8),
              ),
            )
                .animate(delay: 500.ms)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
