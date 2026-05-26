import 'package:cloud_firestore/cloud_firestore.dart';

class SpiritualNoteModel {
  const SpiritualNoteModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.note,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String userId;
  final String userName;
  final String note;
  final DateTime createdAt;
  final String createdBy;

  factory SpiritualNoteModel.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    DateTime createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return SpiritualNoteModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      note: (map['note'] ?? '').toString(),
      createdAt: createdAt,
      createdBy: (map['createdBy'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
