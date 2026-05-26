import 'package:cloud_firestore/cloud_firestore.dart';

class ServantAttendanceModel {
  ServantAttendanceModel({
    required this.id,
    required this.servantId,
    required this.servantName,
    required this.servantRole,
    required this.stage,
    required this.stageNorm,
    required this.date,
    required this.dayName,
    required this.attended,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String servantId;
  final String servantName;
  final String servantRole;
  final String stage;
  final String stageNorm;
  final String date;
  final String dayName;
  final bool attended;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ServantAttendanceModel.fromMap(Map<String, dynamic> map) {
    return ServantAttendanceModel(
      id: (map['id'] ?? '').toString(),
      servantId: (map['servantId'] ?? '').toString(),
      servantName: (map['servantName'] ?? '').toString(),
      servantRole: (map['servantRole'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      stageNorm: (map['stage_norm'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      dayName: (map['dayName'] ?? '').toString(),
      attended: map['attended'] == true,
      createdBy: (map['createdBy'] ?? '').toString(),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'servantId': servantId,
      'servantName': servantName,
      'servantRole': servantRole,
      'stage': stage,
      'stage_norm': stageNorm,
      'date': date,
      'dayName': dayName,
      'attended': attended,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
