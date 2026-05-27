import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/notification_service.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  static final NotificationService _notificationService = NotificationService();

  static const List<_ManagerMenuItem> _menuItems = [
    _ManagerMenuItem('Profile', Icons.person_rounded),
    _ManagerMenuItem('All Members', Icons.groups_rounded),
    _ManagerMenuItem('All Classes', Icons.class_rounded),
    _ManagerMenuItem('Add Notification', Icons.campaign_rounded),
    _ManagerMenuItem('FCM Debug', Icons.bug_report_rounded),
    _ManagerMenuItem('Notes', Icons.sticky_note_2_rounded),
    _ManagerMenuItem('Manage Attachments', Icons.attach_file_rounded),
    _ManagerMenuItem('Add Event', Icons.event_available_rounded),
    _ManagerMenuItem('Add Task', Icons.add_task_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final fullName = authProvider.user?.name.trim() ?? '';
    final welcomeName = fullName.isEmpty
        ? 'Manager'
        : fullName.split(RegExp(r'\s+')).first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Home'),
        actions: [
          Builder(
            builder: (context) {
              final userId = context.read<AuthProvider>().user?.id;
              if (userId == null) return const SizedBox.shrink();

              return StreamBuilder<int>(
                stream: _notificationService.watchUnreadCount(userId),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.notificationCenter,
                      );
                    },
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(Icons.notifications_rounded),
                    ),
                  );
                },
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
              ? 4
              : width >= 800
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
                  'Manage summer school activities, classes, and members.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: _menuItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.12,
                    ),
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      return _ManagerMenuCard(item: item);
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

class _ManagerMenuCard extends StatelessWidget {
  const _ManagerMenuCard({required this.item});

  final _ManagerMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.title == 'Profile') {
            Navigator.pushNamed(context, AppRoutes.profile);
            return;
          }
          if (item.title == 'Add Event') {
            Navigator.pushNamed(context, AppRoutes.manageEvents);
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
          if (item.title == 'Manage Attachments') {
            Navigator.pushNamed(context, AppRoutes.manageAttachments);
            return;
          }
          if (item.title == 'Add Task') {
            Navigator.pushNamed(context, AppRoutes.manageTasks);
            return;
          }
          if (item.title == 'All Classes') {
            Navigator.pushNamed(context, AppRoutes.allClasses);
            return;
          }
          if (item.title == 'All Members') {
            Navigator.pushNamed(context, AppRoutes.allMembers);
            return;
          }
          if (item.title == 'Add Notification') {
            Navigator.pushNamed(context, AppRoutes.sendNotification);
            return;
          }
          if (item.title == 'FCM Debug') {
            Navigator.pushNamed(context, AppRoutes.debugFcm);
            return;
          }
          // TODO: implement other manager menu actions
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7FBFF), Color(0xFFFFFFFF)],
            ),
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

class _ManagerMenuItem {
  const _ManagerMenuItem(this.title, this.icon);

  final String title;
  final IconData icon;
}
