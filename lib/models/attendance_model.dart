import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.stage,
    required this.stageNorm,
    required this.date,
    required this.dayNameEnglish,
    required this.dayNameArabic,
    required this.isPresent,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String stage;
  final String stageNorm;
  final String date;
  final String dayNameEnglish;
  final String dayNameArabic;
  final bool isPresent;
  final DateTime updatedAt;
  final String updatedBy;

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: (map['id'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString(),
      studentName: (map['studentName'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      stageNorm: (map['stage_norm'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      dayNameEnglish: (map['dayNameEnglish'] ?? '').toString(),
      dayNameArabic: (map['dayNameArabic'] ?? '').toString(),
      isPresent: map['isPresent'] == true,
      updatedAt: _parseDateTime(map['updatedAt']),
      updatedBy: (map['updatedBy'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'stage': stage,
      'stage_norm': stageNorm,
      'date': date,
      'dayNameEnglish': dayNameEnglish,
      'dayNameArabic': dayNameArabic,
      'isPresent': isPresent,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
