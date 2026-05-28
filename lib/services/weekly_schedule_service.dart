import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/models/weekly_schedule_item_model.dart';
import 'package:summerschool/services/notification_service.dart';

class WeeklyScheduleService {
  WeeklyScheduleService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  static const String collection = 'weekly_schedules';

  CollectionReference<Map<String, dynamic>> get _weeklySchedules =>
      _firestore.collection(collection);

  String generateId() => _weeklySchedules.doc().id;

  static String normalizeStage(String stage) =>
      stage.replaceAll(' ', '').toLowerCase();

  Stream<List<WeeklyScheduleItemModel>> watchWeeklySchedule({
    required String stage,
    required String day,
  }) {
    final stageNorm = normalizeStage(stage);
    debugPrint(
      '[WeeklySchedule] watch query stage_norm="$stageNorm" day="$day" (client-side sort by startTime)',
    );

    return _weeklySchedules
        .where('stage_norm', isEqualTo: stageNorm)
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[WeeklySchedule] firestore snapshot received docs=${snapshot.docs.length}',
          );
          final items =
              snapshot.docs
                  .map((doc) => WeeklyScheduleItemModel.fromMap(doc.data()))
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
          return items;
        });
  }

  Future<void> addItem(
    WeeklyScheduleItemModel item, {
    dynamic senderUserModel,
  }) async {
    await _ensureNoDuplicate(item: item);
    await _weeklySchedules.doc(item.id).set(item.toMap());
    debugPrint('[WeeklySchedule] item added id=${item.id} day=${item.day}');

    // Trigger automatic notification for schedule update
    if (senderUserModel != null) {
      try {
        await _notificationService.createAutomaticNotification(
          sender: senderUserModel,
          type: 'schedule',
          title: 'Schedule Updated',
          body: 'The stage schedule was updated: ${item.stage}',
          targetStages: [item.stage],
          relatedId: item.id,
        );
      } catch (e) {
        debugPrint('[WeeklySchedule] notification error: $e');
      }
    }
  }

  Future<void> updateItem(
    WeeklyScheduleItemModel item, {
    dynamic senderUserModel,
  }) async {
    await _ensureNoDuplicate(item: item, excludeId: item.id);
    await _weeklySchedules.doc(item.id).update(item.toMap());
    debugPrint('[WeeklySchedule] item updated id=${item.id} day=${item.day}');

    // Trigger automatic notification for schedule update
    if (senderUserModel != null) {
      try {
        await _notificationService.createAutomaticNotification(
          sender: senderUserModel,
          type: 'schedule',
          title: 'Schedule Updated',
          body: 'The stage schedule was updated: ${item.stage}',
          targetStages: [item.stage],
          relatedId: item.id,
        );
      } catch (e) {
        debugPrint('[WeeklySchedule] notification error: $e');
      }
    }
  }

  Future<void> deleteItem(String id) async {
    await _weeklySchedules.doc(id).delete();
    debugPrint('[WeeklySchedule] item deleted id=$id');
  }

  Future<void> _ensureNoDuplicate({
    required WeeklyScheduleItemModel item,
    String? excludeId,
  }) async {
    final query = await _weeklySchedules
        .where('stage_norm', isEqualTo: item.stageNorm)
        .where('day', isEqualTo: item.day)
        .get();

    final hasDuplicate = query.docs
        .where((d) => d.id != excludeId)
        .map((d) => WeeklyScheduleItemModel.fromMap(d.data()))
        .any(
          (existing) =>
              existing.subject == item.subject &&
              (existing.customSubject ?? '') == (item.customSubject ?? '') &&
              existing.startTime == item.startTime &&
              existing.endTime == item.endTime,
        );
    if (hasDuplicate) {
      throw Exception('Duplicate schedule item is not allowed.');
    }
  }
}
