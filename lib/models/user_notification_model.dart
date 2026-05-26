import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationModel {
  UserNotificationModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String notificationId;
  final String userId;
  final bool isRead;
  final DateTime createdAt;

  factory UserNotificationModel.fromMap(Map<String, dynamic> map) {
    return UserNotificationModel(
      id: (map['id'] ?? '').toString(),
      notificationId: (map['notificationId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      isRead: map['isRead'] == true,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
