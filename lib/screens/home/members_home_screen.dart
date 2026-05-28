import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/widgets/common/notification_popup.dart';
import 'package:summerschool/services/notification_service.dart';

class MembersHomeScreen extends StatelessWidget {
  const MembersHomeScreen({super.key});

  static final NotificationService _notificationService = NotificationService();

  // TOP PRIORITIES: Daily Actions
  static const List<_MenuItem> _topPriorityItems = [
    _MenuItem('Schedule', Icons.calendar_month_rounded),
    _MenuItem('Attendance', Icons.fact_check_rounded),
    _MenuItem('My Tasks', Icons.task_alt_rounded),
    _MenuItem('Points', Icons.emoji_events_rounded),
  ];

  // SECONDARY: Info & Schedule
  static const List<_MenuItem> _secondaryItems = [
    _MenuItem('Visits', Icons.home_work_rounded),
    _MenuItem('Events', Icons.event_rounded),
    _MenuItem('Class', Icons.class_rounded),
    _MenuItem('Attachments', Icons.attach_file_rounded),
    _MenuItem('Notes', Icons.sticky_note_2_rounded),
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

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(), // Remove "Members Home" title
        actions: [
          // Profile icon action button
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_rounded),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
          if (userId != null)
            StreamBuilder<int>(
              stream: _notificationService.watchUnreadCount(userId),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return _NotificationBellDropdown(unread: unread);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $welcomeName',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
            const SizedBox(height: 24),
            // TOP PRIORITIES Section
            Text(
              'Top Priorities',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildGridSection(_topPriorityItems),
            const SizedBox(height: 28),
            // SECONDARY Section
            Text(
              'Info & Schedule',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildGridSection(_secondaryItems),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSection(List<_MenuItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 5
            : width >= 850
            ? 4
            : width >= 600
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _MenuCard(item: item);
          },
        );
      },
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
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  item.icon,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
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

class _NotificationBellDropdown extends StatelessWidget {
  const _NotificationBellDropdown({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      offset: const Offset(0, 12),
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 350),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 350,
            height: 400,
            child: NotificationPopup(width: 350, maxHeight: 400),
          ),
        ),
      ],
      child: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_rounded, size: 24),
      ),
    );
  }
}
