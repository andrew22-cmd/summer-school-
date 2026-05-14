import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.eventDate,
    required this.time,
    required this.location,
    required this.dayName,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.createdByName,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime eventDate;
  final String time;
  final String location;
  final String dayName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? createdByName;
  final String? imageUrl;

  factory EventModel.fromMap(Map<String, dynamic> map) {
    final dateRaw = map['eventDate'] ?? map['date'];
    return EventModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      date: _parseDate(dateRaw),
      eventDate: _parseDate(dateRaw),
      time: (map['time'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      dayName: (map['dayName'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDate(map['updatedAt']) : null,
      createdBy: (map['createdBy'] ?? '').toString(),
      createdByName: map['createdByName']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'eventDate': Timestamp.fromDate(eventDate),
      'expiresAt': Timestamp.fromDate(eventDate.add(const Duration(days: 3))),
      'time': time,
      'location': location,
      'dayName': dayName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'imageUrl': imageUrl,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
