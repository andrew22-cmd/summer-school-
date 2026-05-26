import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/servant_attendance_model.dart';
import 'package:summerschool/models/user_model.dart';

class ServantsAttendanceService {
  ServantsAttendanceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'servants_attendance';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static String normalizeStage(String stage) =>
      stage.trim().replaceAll(' ', '').toLowerCase();

  static String dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static String dayNameArabic(DateTime date) {
    switch (DateTime(date.year, date.month, date.day).weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
      default:
        return 'الأحد';
    }
  }

  bool _isServantRole(String role) {
    final r = role.trim().toLowerCase();
    return r == 'member' || r == 'member_manager';
  }

  bool _canAccessStage({
    required String requesterRole,
    required String requesterStage,
    required String itemStage,
  }) {
    final role = requesterRole.trim().toLowerCase();
    if (role == 'manager') return true;
    return normalizeStage(requesterStage) == normalizeStage(itemStage);
  }

  Stream<List<String>> watchServantStages() {
    return _users.snapshots().map((snap) {
      final set = <String>{};
      for (final doc in snap.docs) {
        final map = doc.data();
        final role = (map['role'] ?? '').toString().toLowerCase();
        if (!_isServantRole(role)) continue;
        final stage = (map['stage'] ?? '').toString().trim();
        if (stage.isEmpty) continue;
        set.add(stage);
      }
      final list = set.toList()..sort();
      return list;
    });
  }

  Stream<List<UserModel>> watchServants({
    required String requesterRole,
    required String requesterStage,
    String? selectedStage,
    String? requesterUserId,
  }) {
    return _users.snapshots().map((snap) {
      final role = requesterRole.trim().toLowerCase();
      final stageTarget = (selectedStage ?? '').trim();

      final list = <UserModel>[];
      for (final doc in snap.docs) {
        final map = doc.data();
        final user = UserModel.fromMap(map);
        final userRole = user.role.value.toLowerCase();
        if (!_isServantRole(userRole)) continue;

        if (role == 'member') {
          if (requesterUserId == null || requesterUserId.trim().isEmpty) {
            continue;
          }
          if (user.id != requesterUserId.trim()) continue;
          list.add(user);
          continue;
        }

        if (role == 'member_manager') {
          if (!_canAccessStage(
            requesterRole: role,
            requesterStage: requesterStage,
            itemStage: user.stage,
          )) {
            continue;
          }
          list.add(user);
          continue;
        }

        if (role == 'manager') {
          if (stageTarget.isNotEmpty &&
              normalizeStage(user.stage) != normalizeStage(stageTarget)) {
            continue;
          }
          list.add(user);
        }
      }

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Stream<List<ServantAttendanceModel>> watchAttendanceForDate({
    required DateTime date,
    required String requesterRole,
    required String requesterStage,
    String? selectedStage,
    String? requesterUserId,
  }) {
    final dateStr = dateKey(date);
    final role = requesterRole.trim().toLowerCase();
    final stageTarget = (selectedStage ?? '').trim();

    final q = _firestore
        .collection(collection)
        .where('date', isEqualTo: dateStr);

    return q.snapshots().map((snap) {
      final list = <ServantAttendanceModel>[];
      for (final doc in snap.docs) {
        final model = ServantAttendanceModel.fromMap(doc.data());

        if (role == 'member') {
          if (requesterUserId == null || requesterUserId.trim().isEmpty) {
            continue;
          }
          if (model.servantId != requesterUserId.trim()) continue;
          list.add(model);
          continue;
        }

        if (role == 'member_manager') {
          if (!_canAccessStage(
            requesterRole: role,
            requesterStage: requesterStage,
            itemStage: model.stage,
          )) {
            continue;
          }
          list.add(model);
          continue;
        }

        if (role == 'manager') {
          if (stageTarget.isNotEmpty &&
              normalizeStage(model.stage) != normalizeStage(stageTarget)) {
            continue;
          }
          list.add(model);
        }
      }

      list.sort(
        (a, b) =>
            a.servantName.toLowerCase().compareTo(b.servantName.toLowerCase()),
      );
      return list;
    });
  }

  Future<void> saveAttendance({
    required String stage,
    required DateTime date,
    required List<UserModel> servants,
    required Map<String, bool> attendedByServantId,
    required String createdBy,
  }) async {
    final normalizedStage = normalizeStage(stage);
    final dateStr = dateKey(date);
    final dayName = dayNameArabic(date);
    final now = DateTime.now();

    final batch = _firestore.batch();
    for (final servant in servants) {
      final attended = attendedByServantId[servant.id] ?? false;
      final docId = '${dateStr}_${servant.id}';
      final ref = _firestore.collection(collection).doc(docId);

      final model = ServantAttendanceModel(
        id: docId,
        servantId: servant.id,
        servantName: servant.name,
        servantRole: servant.role.value,
        stage: servant.stage,
        stageNorm: normalizedStage,
        date: dateStr,
        dayName: dayName,
        attended: attended,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );

      batch.set(ref, model.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint(
      '[ServantsAttendanceService] saved attendance stage="$stage" date="$dateStr" count=${servants.length}',
    );
  }
}
