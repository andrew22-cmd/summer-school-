import 'package:cloud_firestore/cloud_firestore.dart';

class SpiritualNotebookModel {
  SpiritualNotebookModel({
    required this.userId,
    required this.weekStartDate, // stored as yyyy-MM-dd
    required this.entries,
    this.updatedAt,
  });

  final String userId;
  final String weekStartDate;
  final Map<String, Map<String, dynamic>> entries;
  final DateTime? updatedAt;

  factory SpiritualNotebookModel.empty({
    required String userId,
    required String weekStartDate,
  }) {
    final days = [
      'saturday',
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
    ];

    final Map<String, Map<String, dynamic>> entries = {};
    for (final d in days) {
      entries[d] = {
        'baker': false,
        'sleepPrayer': false,
        'communion': false,
        'newTestament': false,
        'oldTestament': false,
        'mass': false,
        'confession': false,
      };
    }

    return SpiritualNotebookModel(
      userId: userId,
      weekStartDate: weekStartDate,
      entries: entries,
      updatedAt: null,
    );
  }

  factory SpiritualNotebookModel.fromMap(Map<String, dynamic> map) {
    final entriesMap = <String, Map<String, dynamic>>{};
    if (map['entries'] is Map) {
      (map['entries'] as Map).forEach((key, value) {
        if (value is Map) {
          entriesMap[key.toString()] = Map<String, dynamic>.from(value);
        }
      });
    }

    DateTime? updated;
    if (map['updatedAt'] is Timestamp) {
      updated = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      updated = DateTime.tryParse(map['updatedAt']);
    }

    return SpiritualNotebookModel(
      userId: map['userId']?.toString() ?? '',
      weekStartDate: map['weekStartDate']?.toString() ?? '',
      entries: entriesMap,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'weekStartDate': weekStartDate,
      'entries': entries,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
