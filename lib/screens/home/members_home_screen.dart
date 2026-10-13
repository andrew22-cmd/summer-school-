import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/widgets/common/notification_popup.dart';
import 'package:summerschool/services/notification_service.dart';
import 'package:summerschool/providers/locale_provider.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

class MembersHomeScreen extends StatelessWidget {
  const MembersHomeScreen({super.key});

  static final NotificationService _notificationService = NotificationService();

  // TOP PRIORITIES: Daily Actions
  static const List<_MenuItem> _topPriorityItems = [
    _MenuItem('Schedule', Icons.calendar_month_rounded),
    _MenuItem('Attendance', Icons.fact_check_rounded),
    _MenuItem('My Tasks', Icons.task_alt_rounded),
    _MenuItem('Taweyat', Icons.emoji_events_rounded),
  ];

  // SECONDARY: Info & Schedule
  static const List<_MenuItem> _secondaryItems = [
    _MenuItem('Visits', Icons.home_work_rounded),
    _MenuItem('Events', Icons.event_rounded),
    _MenuItem('Class', Icons.class_rounded),
    _MenuItem('Attachments', Icons.attach_file_rounded),
    _MenuItem('Spiritual Notes', Icons.sticky_note_2_rounded),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: context.tr('select_lang'),
                  onSelected: (value) async {
                    final localeProv = context.read<LocaleProvider>();
                    if (value == 'en') {
                      await localeProv.setLocale(const Locale('en'));
                    } else if (value == 'ar') {
                      await localeProv.setLocale(const Locale('ar'));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('select_lang'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'en', child: Text('English 🇬🇧')),
                    PopupMenuItem(value: 'ar', child: Text('العربية 🇪🇬')),
                  ],
                ),
                const SizedBox(width: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('profile'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (userId != null)
                  StreamBuilder<int>(
                    stream: _notificationService.watchUnreadCount(userId),
                    builder: (context, snapshot) {
                      final unread = snapshot.data ?? 0;
                      return _NotificationBellDropdown(unread: unread);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('welcome_name').replaceAll('{name}', welcomeName),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('blessed_day'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('top_priorities'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildGridSection(_topPriorityItems),
              const SizedBox(height: 28),
              Text(
                context.tr('info_schedule'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildGridSection(_secondaryItems),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
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
                  label: Text(context.tr('logout')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
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
          if (item.title == 'Spiritual Notes') {
            Navigator.pushNamed(context, AppRoutes.spiritualNotebook);
            return;
          }
          if (item.title == 'Class') {
            Navigator.pushNamed(context, AppRoutes.classMembers);
            return;
          }
          if (item.title == 'Taweyat') {
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
                context.tr(item.title),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_rounded, size: 28),
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('notifications'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
