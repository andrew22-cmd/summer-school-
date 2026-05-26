import 'package:flutter/material.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/screens/attendance/attendance_screen.dart';
import 'package:summerschool/screens/follow_up/follow_up_students_screen.dart';
import 'package:summerschool/screens/manager/manager_points_leaderboard_screen.dart';
import 'package:summerschool/screens/schedule/schedule_screen.dart';

class ManagerClassDetailsScreen extends StatelessWidget {
  const ManagerClassDetailsScreen({super.key, required this.selectedStage});

  final String selectedStage;

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[
      _FeatureItem(
        title: 'Attendance',
        subtitle: 'View class attendance (read only)',
        icon: Icons.fact_check_rounded,
        onTap: () {
          debugPrint(
            '[Manager][ClassDetails] navigation -> AttendanceScreen stage="$selectedStage" readOnly=true',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AttendanceScreen(forcedStage: selectedStage, readOnly: true),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'Visits',
        subtitle: 'View weekly visits (read only)',
        icon: Icons.volunteer_activism_rounded,
        onTap: () {
          debugPrint(
            '[Manager][ClassDetails] navigation -> FollowUpStudentsScreen stage="$selectedStage" readOnly=true',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowUpStudentsScreen(
                forcedStage: selectedStage,
                readOnly: true,
              ),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'Weekly Stage Schedule',
        subtitle: 'View weekly schedule for this class',
        icon: Icons.calendar_month_rounded,
        onTap: () {
          debugPrint(
            '[Manager][ClassDetails] navigation -> ScheduleScreen stage="$selectedStage" readOnly=true',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ScheduleScreen(forcedStage: selectedStage, readOnly: true),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'Youth Points',
        subtitle: 'View leaderboard (name + total points)',
        icon: Icons.emoji_events_rounded,
        onTap: () {
          debugPrint(
            '[Manager][ClassDetails] navigation -> ManagerPointsLeaderboardScreen stage="$selectedStage"',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ManagerPointsLeaderboardScreen(stage: selectedStage),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Class Monitoring'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1200
                ? 4
                : width >= 820
                ? 2
                : 1;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blueGrey.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      'You are viewing class: $selectedStage',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Read only mode: editing is disabled for manager in this section.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.7,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _FeatureCard(item: item);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(item.icon, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                item.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
