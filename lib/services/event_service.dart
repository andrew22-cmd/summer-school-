import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/models/event_model.dart';

class EventService {
  EventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  String generateId() => _events.doc().id;

  Future<void> createEvent(EventModel event) async {
    try {
      await _events.doc(event.id).set(event.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Failed to create event (${e.code}): ${e.message}');
    }
  }

  Future<EventModel?> getEvent(String id) async {
    try {
      final doc = await _events.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return EventModel.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      throw Exception('Failed to get event (${e.code}): ${e.message}');
    }
  }

  Stream<List<EventModel>> watchEvents() {
    try {
      // Some older documents may not have `expiresAt`. To avoid excluding
      // those, fetch by `eventDate` and filter client-side: include if
      // `expiresAt` is missing or expiresAt > now.
      final now = DateTime.now();
      return _events.orderBy('eventDate', descending: false).snapshots().map((
        snap,
      ) {
        final list = <EventModel>[];
        for (final d in snap.docs) {
          final data = d.data();
          if (data.isEmpty) continue;
          final expiresRaw = data['expiresAt'];
          if (expiresRaw == null) {
            // treat missing expiresAt as not expired (for backward compatibility)
            list.add(EventModel.fromMap(data));
            continue;
          }
          DateTime expires;
          if (expiresRaw is Timestamp) {
            expires = expiresRaw.toDate();
          } else if (expiresRaw is DateTime) {
            expires = expiresRaw;
          } else {
            expires =
                DateTime.tryParse(expiresRaw.toString()) ??
                DateTime.now().subtract(const Duration(days: 1));
          }
          if (expires.isAfter(now)) {
            list.add(EventModel.fromMap(data));
          }
        }
        return list;
      });
    } on FirebaseException catch (e) {
      debugPrint('Failed to watch events: ${e.message}');
      rethrow;
    }
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      // If updating eventDate, ensure expiresAt is recalculated
      if (data.containsKey('eventDate') && data['eventDate'] is DateTime) {
        final dt = data['eventDate'] as DateTime;
        data['expiresAt'] = Timestamp.fromDate(dt.add(const Duration(days: 3)));
        data['dayName'] = _dayNameFromDate(dt);
      }
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _events.doc(id).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Failed to update event (${e.code}): ${e.message}');
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _events.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception('Failed to delete event (${e.code}): ${e.message}');
    }
  }

  Future<int> deleteExpiredEvents() async {
    try {
      final nowTs = Timestamp.fromDate(DateTime.now());
      final snapshot = await _events
          .where('expiresAt', isLessThanOrEqualTo: nowTs)
          .get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snapshot.docs.length;
    } on FirebaseException catch (e) {
      throw Exception(
        'Failed to delete expired events (${e.code}): ${e.message}',
      );
    }
  }

  String _dayNameFromDate(DateTime d) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(d.weekday - 1) % 7];
  }
}
