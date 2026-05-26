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
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(child: Text('يجب تسجيل الدخول أولاً')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          StreamBuilder<int>(
            stream: _service.watchUnreadCount(user.id),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount <= 0) {
                return const SizedBox.shrink();
              }
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
                      '$unreadCount غير مقروء',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationCenterItemModel>>(
        stream: _service.watchNotificationCenter(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات'));
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationTile(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(NotificationCenterItemModel notif) {
    final formattedDate = DateFormat(
      'dd/MM/yyyy - hh:mm a',
    ).format(notif.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: notif.isRead ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!notif.isRead) {
            _markAsRead(notif.userNotificationId);
          }
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
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          formattedDate,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (notif.isImportant)
                          const Icon(
                            Icons.label_important_rounded,
                            color: Colors.redAccent,
                            size: 18,
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
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
