import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/services/local_storage_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleStartup();
  }

  Future<void> _handleStartup() async {
    debugPrint('Splash started');
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Check onboarding flag and navigate accordingly
    try {
      final localStorage = context.read<LocalStorageService>();
      final onboardingCompleted = await localStorage.getOnboardingCompleted();
      if (!mounted) return;

      final nextRoute = onboardingCompleted
          ? AppRoutes.home
          : AppRoutes.onboarding;
      debugPrint('Navigating to $nextRoute');
      Navigator.pushReplacementNamed(context, nextRoute);
    } catch (e) {
      // If provider not found or any error, fallback to login
      debugPrint('Failed to read onboarding status: $e');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF1FF), AppColors.background],
          ),
        ),
        child: Center(
          child:
              Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 160,
                          width: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 160,
                            width: 160,
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(
                              Icons.church_rounded,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Saint Mina Summer School',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 900.ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                  ),
        ),
      ),
    );
  }
}
