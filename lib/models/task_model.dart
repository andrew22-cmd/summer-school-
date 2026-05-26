import 'package:cloud_firestore/cloud_firestore.dart';

class TaskHistoryEntry {
  final String changedBy;
  final String changedByName;
  final String fieldName;
  final String oldValue;
  final String newValue;
  final DateTime changedAt;

  TaskHistoryEntry({
    required this.changedBy,
    required this.changedByName,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.changedAt,
  });

  factory TaskHistoryEntry.fromMap(Map<String, dynamic> map) {
    return TaskHistoryEntry(
      changedBy: (map['changedBy'] ?? '').toString(),
      changedByName: (map['changedByName'] ?? '').toString(),
      fieldName: (map['fieldName'] ?? '').toString(),
      oldValue: (map['oldValue'] ?? '').toString(),
      newValue: (map['newValue'] ?? '').toString(),
      changedAt: (map['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'changedBy': changedBy,
      'changedByName': changedByName,
      'fieldName': fieldName,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedAt': Timestamp.fromDate(changedAt),
    };
  }
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedToUserId,
    required this.assignedToName,
    required this.assignedToRole,
    required this.assignedByUserId,
    required this.assignedByName,
    required this.assignedByRole,
    required this.stage,
    required this.stageNorm,
    required this.dueDate,
    required this.isCompleted,
    required this.completedAt,
    required this.createdAt,
    this.status = 'pending',
    this.lastEditedBy,
    this.lastEditedAt,
    this.history = const [],
  });

  final String id;
  final String title;
  final String description;
  final String assignedToUserId;
  final String assignedToName;
  final String assignedToRole;
  final String assignedByUserId;
  final String assignedByName;
  final String assignedByRole;
  final String stage;
  final String stageNorm;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String status; // pending, in_progress, completed, overdue
  final String? lastEditedBy;
  final DateTime? lastEditedAt;
  final List<TaskHistoryEntry> history;

  factory TaskModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String)
        return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    final createdAtRaw = map['createdAt'];
    final createdAt = parseDate(createdAtRaw);

    final historyList =
        (map['history'] as List<dynamic>?)
            ?.map((e) => TaskHistoryEntry.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return TaskModel(
      id: (map['id'] ?? docId).toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      assignedToUserId: (map['assignedToUserId'] ?? '').toString(),
      assignedToName: (map['assignedToName'] ?? '').toString(),
      assignedToRole: (map['assignedToRole'] ?? '').toString(),
      assignedByUserId: (map['assignedByUserId'] ?? '').toString(),
      assignedByName: (map['assignedByName'] ?? '').toString(),
      assignedByRole: (map['assignedByRole'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      stageNorm: (map['stage_norm'] ?? '').toString(),
      dueDate: parseDate(map['dueDate'], fallback: createdAt),
      isCompleted: map['isCompleted'] == true,
      completedAt: map['completedAt'] == null
          ? null
          : parseDate(map['completedAt'], fallback: createdAt),
      createdAt: createdAt,
      status: (map['status'] ?? 'pending').toString(),
      lastEditedBy: map['lastEditedBy'] as String?,
      lastEditedAt: map['lastEditedAt'] == null
          ? null
          : parseDate(map['lastEditedAt']),
      history: historyList,
    );
  }
}
