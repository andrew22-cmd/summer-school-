import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetRoles,
    required this.targetStages,
    required this.createdBy,
    required this.createdAt,
    required this.isImportant,
    this.type = 'manual',
    this.relatedId = '',
    this.senderId = '',
    this.receiverId = '',
    this.receiverRole = '',
    this.receiverStage = '',
    this.topic = '',
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final List<String> targetRoles;
  final List<String> targetStages;
  final String createdBy;
  final DateTime createdAt;
  final bool isImportant;
  final String type; // manual, task, attachment, event, schedule, visits
  final String relatedId; // task/attachment/event/schedule id for reference
  final String senderId;
  final String receiverId;
  final String receiverRole;
  final String receiverStage;
  final String topic;
  final bool isRead;

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    List<String> toStringList(dynamic value) {
      if (value is Iterable) {
        return value.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    final parsedRoles = toStringList(map['targetRoles']);
    final parsedStages = toStringList(map['targetStages']);
    final fallbackRole = (map['targetRole'] ?? '').toString().trim();
    final fallbackStage = (map['targetStage'] ?? '').toString().trim();

    return AppNotificationModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      targetRoles: parsedRoles.isNotEmpty
          ? parsedRoles
          : (fallbackRole.isEmpty ? <String>[] : <String>[fallbackRole]),
      targetStages: parsedStages.isNotEmpty
          ? parsedStages
          : (fallbackStage.isEmpty ? <String>[] : <String>[fallbackStage]),
      createdBy: (map['createdBy'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']),
      isImportant: map['isImportant'] == true,
      type: (map['type'] ?? 'manual').toString(),
      relatedId: (map['relatedId'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      receiverId: (map['receiverId'] ?? '').toString(),
      receiverRole: (map['receiverRole'] ?? '').toString(),
      receiverStage: (map['receiverStage'] ?? '').toString(),
      topic: (map['topic'] ?? '').toString(),
      isRead: map['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'targetRoles': targetRoles,
      'targetStages': targetStages,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isImportant': isImportant,
      'type': type,
      'relatedId': relatedId,
      'senderId': senderId,
      'receiverId': receiverId,
      'receiverRole': receiverRole,
      'receiverStage': receiverStage,
      'topic': topic,
      'isRead': isRead,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
