import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/notification_service.dart';

class MembersHomeScreen extends StatelessWidget {
  const MembersHomeScreen({super.key});

  static final NotificationService _notificationService = NotificationService();

  static const List<_MenuItem> _menuItems = [
    _MenuItem('Profile', Icons.person_rounded),
    _MenuItem('Class', Icons.class_rounded),
    _MenuItem('Attendance', Icons.fact_check_rounded),
    _MenuItem('Events', Icons.event_rounded),
    _MenuItem('Notes', Icons.sticky_note_2_rounded),
    _MenuItem('My Tasks', Icons.task_alt_rounded),
    _MenuItem('Schedule', Icons.calendar_month_rounded),
    _MenuItem('Attachments', Icons.attach_file_rounded),
    _MenuItem('Points', Icons.emoji_events_rounded),
    _MenuItem('Visits', Icons.home_work_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.id;
    final fullName = authProvider.user?.name.trim() ?? '';
    final welcomeName = fullName.isEmpty
        ? 'Student'
        : fullName.split(RegExp(r'\s+')).first;

    final isMemberManager = authProvider.isMemberManager;
    final menuItems = List<_MenuItem>.from(_menuItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members Home'),
        actions: [
          if (userId != null)
            StreamBuilder<int>(
              stream: _notificationService.watchUnreadCount(userId),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.notificationCenter);
                  },
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_rounded),
                  ),
                );
              },
            ),
          TextButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1100
              ? 5
              : width >= 850
              ? 4
              : width >= 600
              ? 3
              : 2;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $welcomeName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMemberManager
                      ? 'Member Manager access enabled.'
                      : 'Have a blessed and productive day.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (isMemberManager) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.manage_accounts_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Extra permissions are active'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: menuItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return _MenuCard(item: item);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (item.title == 'Profile') {
            Navigator.pushNamed(context, AppRoutes.profile);
            return;
          }
          if (item.title == 'Events') {
            Navigator.pushNamed(context, AppRoutes.events);
            return;
          }
          if (item.title == 'Notes') {
            Navigator.pushNamed(context, AppRoutes.spiritualNotebook);
            return;
          }
          if (item.title == 'Class') {
            Navigator.pushNamed(context, AppRoutes.classMembers);
            return;
          }
          if (item.title == 'Points') {
            Navigator.pushNamed(context, AppRoutes.points);
            return;
          }
          if (item.title == 'Attachments') {
            Navigator.pushNamed(context, AppRoutes.attachments);
            return;
          }
          if (item.title == 'Schedule') {
            Navigator.pushNamed(context, AppRoutes.schedule);
            return;
          }
          if (item.title == 'My Tasks') {
            Navigator.pushNamed(context, AppRoutes.myTasks);
            return;
          }
          if (item.title == 'Attendance') {
            Navigator.pushNamed(context, AppRoutes.attendance);
            return;
          }
          if (item.title == 'Visits') {
            Navigator.pushNamed(context, AppRoutes.followUpStudents);
            return;
          }
          // TODO: wire other menu actions
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
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
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  item.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.title, this.icon);

  final String title;
  final IconData icon;
}
