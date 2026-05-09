import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/services/local_storage_service.dart';
import 'package:summerschool/widgets/common/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Welcome to Saint Mina',
      subtitle:
          'A calm, beautiful space for your summer school journey, with a simple and friendly experience.',
      icon: Icons.church_rounded,
      accent: Color(0xFF0D3B66),
    ),
    _OnboardingItem(
      title: 'Stay Organized',
      subtitle:
          'Quick access to your school updates, attendance, and important announcements in one place.',
      icon: Icons.event_note_rounded,
      accent: Color(0xFFD4A017),
    ),
    _OnboardingItem(
      title: 'Grow Together',
      subtitle:
          'Everything is designed to feel warm, clean, and easy to use for students and servants.',
      icon: Icons.groups_rounded,
      accent: Color(0xFF2E7D32),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final storage = context.read<LocalStorageService>();
    await storage.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  Future<void> _skip() async {
    await _finishOnboarding();
  }

  void _next() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          'Onboarding',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _skip,
                          child: const Text('Skip'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _OnboardingPage(item: item, textTheme: textTheme);
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_items.length, (index) {
                    final active = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.textDisabled.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: isLastPage ? 'Get Started' : 'Next',
                    onPressed: _next,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    'Continue to Home',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item, required this.textTheme});

  final _OnboardingItem item;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 132,
              width: 132,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.accent.withOpacity(0.16),
                    item.accent.withOpacity(0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 58, color: item.accent),
            ).animate().scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
            ),
            const SizedBox(height: 28),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.04, end: 0),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}
