import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/models/notification_center_item_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/notification_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _service = NotificationService();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in first')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          StreamBuilder<int>(
            stream: _service.watchUnreadCount(user.id),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unreadCount unread',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: NotificationCenterContent(userId: user.id, service: _service),
    );
  }
}

class NotificationCenterContent extends StatelessWidget {
  const NotificationCenterContent({
    super.key,
    required this.userId,
    this.useScrollbar = false,
    NotificationService? service,
  }) : _service = service;

  final String userId;
  final bool useScrollbar;
  final NotificationService? _service;

  NotificationService get service => _service ?? NotificationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationCenterItemModel>>(
      stream: service.watchNotificationCenter(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));

        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty)
          return const Center(child: Text('No notifications'));

        final listView = ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            return _NotificationTile(
              notif: notif,
              onMarkAsRead: (notificationId) async {
                try {
                  await service.markAsRead(notificationId);
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              onDelete: (notificationId) async {
                try {
                  await service.deleteNotification(notificationId);
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            );
          },
        );

        if (!useScrollbar) return listView;
        return Scrollbar(thumbVisibility: true, child: listView);
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notif,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  final NotificationCenterItemModel notif;
  final Future<void> Function(String notificationId) onMarkAsRead;
  final Future<void> Function(String notificationId) onDelete;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'dd/MM/yyyy - hh:mm a',
    ).format(notif.createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (MediaQuery.of(context).size.width - 24);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: notif.isRead ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.hardEdge,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                if (!notif.isRead) await onMarkAsRead(notif.userNotificationId);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: notif.isRead
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        notif.isImportant
                            ? Icons.priority_high_rounded
                            : Icons.notifications_rounded,
                        color: notif.isImportant
                            ? Colors.redAccent
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Middle expands; trailing is fixed width to avoid overflow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: notif.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                      ),
                                ),
                              ),
                              if (!notif.isRead)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif.body,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formattedDate,
                            maxLines: 2,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (notif.isImportant)
                                const Icon(
                                  Icons.label_important_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              IconButton(
                                tooltip: 'Delete notification',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  await onDelete(notif.userNotificationId);
                                },
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showNotificationsBottomSheet(BuildContext context) async {
  final user = context.read<AuthProvider>().user;
  if (user == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
    return;
  }

  final service = NotificationService();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.78,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: NotificationCenterContent(
                userId: user.id,
                service: service,
              ),
            ),
          ],
        ),
      );
    },
  );
}
