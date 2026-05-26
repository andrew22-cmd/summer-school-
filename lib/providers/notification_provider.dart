import 'package:flutter/material.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/models/user_notification_model.dart';
import 'package:summerschool/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  final UserModel user;

  NotificationProvider({
    required this.user,
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  Stream<List<UserNotificationModel>> get notifications =>
      _notificationService.watchUserNotifications(user.id);

  Stream<int> get unreadCount => _notificationService.watchUnreadCount(user.id);

  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead(user.id);
    notifyListeners();
  }
}
