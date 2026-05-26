class NotificationCenterItemModel {
  const NotificationCenterItemModel({
    required this.userNotificationId,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.isImportant,
  });

  final String userNotificationId;
  final String notificationId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final bool isImportant;
}
