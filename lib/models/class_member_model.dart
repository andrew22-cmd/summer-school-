import 'package:cloud_firestore/cloud_firestore.dart';

class ClassMemberModel {
  ClassMemberModel({
    required this.id,
    required this.name,
    required this.stage,
    required this.year,
    required this.phone,
    required this.parentPhone,
    required this.confessionFather,
    required this.totalPoints,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String name;
  final String stage;
  final String year;
  final String phone;
  final String parentPhone;
  final String confessionFather;
  final int totalPoints;
  final DateTime createdAt;
  final String createdBy;

  factory ClassMemberModel.fromMap(Map<String, dynamic> map) {
    return ClassMemberModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      stage: (map['stage'] ?? '').toString(),
      year: (map['year'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      parentPhone: (map['parentPhone'] ?? '').toString(),
      confessionFather: (map['confessionFather'] ?? '').toString(),
      totalPoints: (map['totalPoints'] ?? 0) is int
          ? (map['totalPoints'] ?? 0)
          : int.tryParse((map['totalPoints'] ?? '0').toString()) ?? 0,
      createdAt: _parseCreatedAt(map['createdAt']),
      createdBy: (map['createdBy'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'stage': stage,
      'stage_norm': stage.replaceAll(' ', '').toLowerCase(),
      'year': year,
      'phone': phone,
      'parentPhone': parentPhone,
      'confessionFather': confessionFather,
      'totalPoints': totalPoints,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
