import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/widgets/common/custom_button.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width > 600 ? 480 : width),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms),

                  const SizedBox(height: 26),

                  // Title
                  Text(
                    'Saint Mina',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 12),

                  // Subtitle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFF2B705),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'You are creative',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFF2B705),
                        size: 18,
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 28),

                  // Small icon buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SmallAction(
                        icon: Icons.favorite_rounded,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 14),
                      _SmallAction(
                        icon: Icons.star_rounded,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 14),
                      _SmallAction(
                        icon: Icons.auto_awesome_rounded,
                        color: Colors.orange,
                      ),
                    ],
                  ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.02, end: 0),

                  const SizedBox(height: 36),

                  // Big primary button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'تسجيل الدخول / Login',
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                    ),
                  ),

                  const SizedBox(height: 18),
                  // Verse with decorative background and crosses
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '✝',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '✝',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 16,
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            'دَرِّبِ الطِّفْلَ فِي طَرِيقِهِ، فَمَتَى شَاخَ أَيْضًا لاَ يَحِيدُ عَنْهُ. (أمثال 22: 6)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 320.ms),

                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
