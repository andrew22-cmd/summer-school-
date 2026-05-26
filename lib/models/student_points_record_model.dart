import 'package:cloud_firestore/cloud_firestore.dart';

class StudentPointsRecordModel {
  StudentPointsRecordModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.stage,
    required this.operationType,
    required this.points,
    required this.reason,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    required this.totalPointsBefore,
    required this.totalPointsAfter,
    this.stageNorm,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String stage;
  final String? stageNorm;
  final String operationType; // add | remove
  final int points;
  final String reason;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final int totalPointsBefore;
  final int totalPointsAfter;

  bool get isAdd => operationType.toLowerCase() == 'add';
  int get signedPoints => isAdd ? points : -points;

  factory StudentPointsRecordModel.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse((value ?? '0').toString()) ?? 0;
    }

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return StudentPointsRecordModel(
      id: (map['id'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString(),
      studentName: (map['studentName'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      stageNorm: (map['stage_norm'] ?? map['stageNorm'])?.toString(),
      operationType: (map['operationType'] ?? '').toString(),
      points: parseInt(map['points']),
      reason: (map['reason'] ?? '').toString(),
      createdByUserId: (map['createdByUserId'] ?? '').toString(),
      createdByName: (map['createdByName'] ?? '').toString(),
      createdAt: parseDate(map['createdAt']),
      totalPointsBefore: parseInt(map['totalPointsBefore']),
      totalPointsAfter: parseInt(map['totalPointsAfter']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'stage': stage,
      'stage_norm': stageNorm ?? stage.replaceAll(' ', '').toLowerCase(),
      'operationType': operationType,
      'points': points,
      'reason': reason,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalPointsBefore': totalPointsBefore,
      'totalPointsAfter': totalPointsAfter,
    };
  }
}
