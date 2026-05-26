import 'package:cloud_firestore/cloud_firestore.dart';

class FollowUpModel {
  FollowUpModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.stage,
    required this.stageNorm,
    required this.servantId,
    required this.servantName,
    required this.createdByRole,
    required this.visitDate,
    required this.month,
    required this.year,
    required this.responded,
    required this.visitType,
    required this.summary,
    required this.notes,
    required this.favoriteThing,
    required this.nextFollowUp,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String stage;
  final String stageNorm;
  final String servantId;
  final String servantName;
  final String createdByRole;
  final DateTime visitDate;
  final int month;
  final int year;
  final bool responded;
  final String visitType;
  final String summary;
  final String notes;
  final String favoriteThing;
  final DateTime? nextFollowUp;
  final DateTime createdAt;

  /// Backward-compatible aliases for older weekly visit code paths.
  String get stage_norm => stageNorm;
  DateTime get weekStartDate => visitDate;
  String get currentDate => _formatDate(visitDate);
  String get dayName => _dayName(visitDate);
  bool get contacted => responded;
  DateTime get updatedAt => createdAt;

  FollowUpModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? stage,
    String? stageNorm,
    String? servantId,
    String? servantName,
    String? createdByRole,
    DateTime? visitDate,
    int? month,
    int? year,
    bool? responded,
    String? visitType,
    String? summary,
    String? notes,
    String? favoriteThing,
    DateTime? nextFollowUp,
    DateTime? createdAt,
  }) {
    return FollowUpModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      stage: stage ?? this.stage,
      stageNorm: stageNorm ?? this.stageNorm,
      servantId: servantId ?? this.servantId,
      servantName: servantName ?? this.servantName,
      createdByRole: createdByRole ?? this.createdByRole,
      visitDate: visitDate ?? this.visitDate,
      month: month ?? this.month,
      year: year ?? this.year,
      responded: responded ?? this.responded,
      visitType: visitType ?? this.visitType,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
      favoriteThing: favoriteThing ?? this.favoriteThing,
      nextFollowUp: nextFollowUp ?? this.nextFollowUp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FollowUpModel.fromMap(Map<String, dynamic> map, String docId) {
    final visitDate = _parseDate(
      map['visitDate'] ?? map['weekStartDate'] ?? map['createdAt'],
    );
    final nextFollowUp = map['nextFollowUp'] == null
        ? null
        : _parseDate(map['nextFollowUp']);
    return FollowUpModel(
      id: (map['id'] ?? docId).toString(),
      studentId: (map['studentId'] ?? '').toString(),
      studentName: (map['studentName'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      stageNorm: (map['stage_norm'] ?? map['stageNorm'] ?? '').toString(),
      servantId: (map['servantId'] ?? '').toString(),
      servantName: (map['servantName'] ?? '').toString(),
      createdByRole: (map['createdByRole'] ?? '').toString(),
      visitDate: visitDate,
      month: (map['month'] ?? visitDate.month) is int
          ? (map['month'] ?? visitDate.month)
          : int.tryParse((map['month'] ?? visitDate.month).toString()) ??
                visitDate.month,
      year: (map['year'] ?? visitDate.year) is int
          ? (map['year'] ?? visitDate.year)
          : int.tryParse((map['year'] ?? visitDate.year).toString()) ??
                visitDate.year,
      responded: (map['responded'] ?? map['contacted'] ?? false) == true,
      visitType: (map['visitType'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      favoriteThing: (map['favoriteThing'] ?? '').toString(),
      nextFollowUp: nextFollowUp,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'stage': stage,
      'stage_norm': stageNorm,
      'servantId': servantId,
      'servantName': servantName,
      'createdByRole': createdByRole,
      'visitDate': Timestamp.fromDate(visitDate),
      'month': month,
      'year': year,
      'responded': responded,
      'visitType': visitType,
      'summary': summary,
      'notes': notes,
      'favoriteThing': favoriteThing,
      'nextFollowUp': nextFollowUp == null
          ? null
          : Timestamp.fromDate(nextFollowUp!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  static String _dayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
      default:
        return 'Sunday';
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
