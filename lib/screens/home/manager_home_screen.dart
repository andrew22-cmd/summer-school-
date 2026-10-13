import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/widgets/common/notification_popup.dart';
import 'package:summerschool/services/notification_service.dart';
import 'package:summerschool/providers/locale_provider.dart';
import 'package:summerschool/core/localization/app_localizations.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  static final NotificationService _notificationService = NotificationService();

  static const List<_ManagerMenuItem> _managementOverviewItems = [
    _ManagerMenuItem('All Members', Icons.groups_rounded),
    _ManagerMenuItem('All Classes', Icons.class_rounded),
    _ManagerMenuItem('Notes', Icons.sticky_note_2_rounded),
    _ManagerMenuItem('Manage Attachments', Icons.attach_file_rounded),
  ];

  static const List<_ManagerMenuItem> _quickActionItems = [
    _ManagerMenuItem('Add Notification', Icons.campaign_rounded),
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
        title: const SizedBox.shrink(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    PopupMenuItem(
                      value: 'en',
                      child: Text('English 🇬🇧'),
                    ),
                    PopupMenuItem(
                      value: 'ar',
                      child: Text('العربية 🇪🇬'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                Builder(
                  builder: (context) {
                    final userId = context.read<AuthProvider>().user?.id;
                    if (userId == null) return const SizedBox.shrink();

                    return StreamBuilder<int>(
                      stream: _notificationService.watchUnreadCount(userId),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        return _NotificationBellDropdown(unread: unread);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1200
              ? 4
              : width >= 850
              ? 3
              : 2;

          return Padding(
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
                  context.tr('manager_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        context.tr('management_overview'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _managementOverviewItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.12,
                              ),
                          itemBuilder: (context, index) {
                            final item = _managementOverviewItems[index];
                            return _ManagerMenuCard(item: item);
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('quick_actions'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _quickActionItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.12,
                              ),
                          itemBuilder: (context, index) {
                            final item = _quickActionItems[index];
                            return _ManagerMenuCard(item: item, accented: true);
                          },
                        ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ManagerMenuCard extends StatelessWidget {
  const _ManagerMenuCard({required this.item, this.accented = false});

  final _ManagerMenuItem item;
  final bool accented;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final baseOutline = Theme.of(context).colorScheme.outlineVariant;
    final gradientColors = accented
        ? [primary.withOpacity(0.08), Colors.white]
        : const [Color(0xFFF7FBFF), Color(0xFFFFFFFF)];
    final borderColor = accented ? primary.withOpacity(0.30) : baseOutline;
    final avatarBg = accented
        ? primary.withOpacity(0.14)
        : Theme.of(context).colorScheme.primaryContainer;

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
          // TODO: implement other manager menu actions
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor),
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
                radius: 30,
                backgroundColor: avatarBg,
                child: Icon(item.icon, color: primary, size: 34),
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

class _ManagerMenuItem {
  const _ManagerMenuItem(this.title, this.icon);

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
