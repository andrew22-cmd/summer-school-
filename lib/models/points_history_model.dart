import 'package:cloud_firestore/cloud_firestore.dart';

class PointsHistoryModel {
  PointsHistoryModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.stage,
    required this.operationType,
    required this.points,
    required this.reason,
    required this.createdAt,
    required this.createdBy,
    this.totalPointsAfterOperation = 0,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String stage;
  final String operationType;
  final int points;
  final String reason;
  final DateTime createdAt;
  final String createdBy;
  final int totalPointsAfterOperation;

  factory PointsHistoryModel.fromMap(Map<String, dynamic> map) {
    return PointsHistoryModel(
      id: (map['id'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString(),
      studentName: (map['studentName'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      operationType: (map['operationType'] ?? '').toString(),
      points: (map['points'] ?? 0) is int
          ? (map['points'] ?? 0)
          : int.tryParse((map['points'] ?? '0').toString()) ?? 0,
      reason: (map['reason'] ?? '').toString(),
      createdAt: _parseCreatedAt(map['createdAt']),
      createdBy: (map['createdBy'] ?? '').toString(),
      totalPointsAfterOperation: (map['totalPointsAfterOperation'] ?? 0) is int
          ? (map['totalPointsAfterOperation'] ?? 0)
          : int.tryParse(
                  (map['totalPointsAfterOperation'] ?? '0').toString(),
                ) ??
                0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'stage': stage,
      'stage_norm': stage.replaceAll(' ', '').toLowerCase(),
      'operationType': operationType,
      'points': points,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'totalPointsAfterOperation': totalPointsAfterOperation,
    };
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
