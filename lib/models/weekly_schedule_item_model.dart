import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyScheduleItemModel {
  WeeklyScheduleItemModel({
    required this.id,
    required this.stage,
    required this.stageNorm,
    required this.day,
    required this.subject,
    this.customSubject,
    required this.startTime,
    required this.endTime,
    this.servantName,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String stage;
  final String stageNorm;
  final String day;
  final String subject;
  final String? customSubject;
  final int startTime;
  final int endTime;
  final String? servantName;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;

  String get resolvedSubject {
    if (subject == 'Other' && (customSubject ?? '').trim().isNotEmpty) {
      return customSubject!.trim();
    }
    return subject;
  }

  factory WeeklyScheduleItemModel.fromMap(Map<String, dynamic> map) {
    return WeeklyScheduleItemModel(
      id: (map['id'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      stageNorm: (map['stage_norm'] ?? '').toString(),
      day: (map['day'] ?? '').toString(),
      subject: (map['subject'] ?? '').toString(),
      customSubject: map['customSubject']?.toString(),
      startTime: _parseInt(map['startTime']),
      endTime: _parseInt(map['endTime']),
      servantName: map['servantName']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: _parseDateTime(map['createdAt']),
      createdBy: (map['createdBy'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stage': stage,
      'stage_norm': stageNorm,
      'day': day,
      'subject': subject,
      'customSubject': customSubject,
      'startTime': startTime,
      'endTime': endTime,
      'servantName': servantName,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  WeeklyScheduleItemModel copyWith({
    String? id,
    String? stage,
    String? stageNorm,
    String? day,
    String? subject,
    String? customSubject,
    int? startTime,
    int? endTime,
    String? servantName,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return WeeklyScheduleItemModel(
      id: id ?? this.id,
      stage: stage ?? this.stage,
      stageNorm: stageNorm ?? this.stageNorm,
      day: day ?? this.day,
      subject: subject ?? this.subject,
      customSubject: customSubject ?? this.customSubject,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      servantName: servantName ?? this.servantName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
