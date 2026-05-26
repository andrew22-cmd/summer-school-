import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/models/attendance_model.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/services/class_member_service.dart';

class AttendanceService {
  AttendanceService({
    FirebaseFirestore? firestore,
    ClassMemberService? classMemberService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _classMemberService =
           classMemberService ?? ClassMemberService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ClassMemberService _classMemberService;

  static const String collection = 'attendance';

  static String normalizeStage(String stage) =>
      ClassMemberService.normalizeStage(stage);

  static String dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static String dayNameEnglish(DateTime date) {
    switch (DateTime(date.year, date.month, date.day).weekday) {
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

  static String dayNameArabic(DateTime date) {
    switch (DateTime(date.year, date.month, date.day).weekday) {
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

  Stream<List<ClassMemberModel>> watchStudentsForStage(String stage) {
    return _classMemberService.watchMembersForStage(stage);
  }

  Stream<List<AttendanceModel>> watchAttendanceForStage(String stage) {
    final normalized = normalizeStage(stage);
    if (normalized.isEmpty) {
      debugPrint(
        '[STREAM] AttendanceService.watchAttendanceForStage() empty stage -> empty stream',
      );
      return Stream<List<AttendanceModel>>.value(const []);
    }

    debugPrint(
      '[STREAM] AttendanceService.watchAttendanceForStage() stage="$stage" stage_norm="$normalized"',
    );

    final query = _firestore
        .collection(collection)
        .where('stage_norm', isEqualTo: normalized);

    return query.snapshots().map((snap) {
      debugPrint(
        '[STREAM] AttendanceService snapshot docs=${snap.docs.length}',
      );
      final list =
          snap.docs.map((doc) {
            final model = AttendanceModel.fromMap(doc.data());
            debugPrint(
              '[STREAM] attendance doc id=${model.id} student=${model.studentName} date=${model.date} present=${model.isPresent}',
            );
            return model;
          }).toList()..sort((a, b) {
            final dateCmp = b.date.compareTo(a.date);
            if (dateCmp != 0) return dateCmp;
            return a.studentName.compareTo(b.studentName);
          });
      return list;
    });
  }

  Future<void> saveAttendance({
    required String stage,
    required DateTime date,
    required List<ClassMemberModel> students,
    required Map<String, bool> attendanceByStudentId,
    required String updatedBy,
  }) async {
    final normalizedStage = normalizeStage(stage);
    final dateString = dateKey(date);
    final english = dayNameEnglish(date);
    final arabic = dayNameArabic(date);
    final cleanUpdatedBy = updatedBy.trim().isEmpty
        ? 'local_admin'
        : updatedBy.trim();

    debugPrint(
      '[ATTENDANCE SAVE] stage="$stage" normalized="$normalizedStage" date="$dateString" students=${students.length}',
    );

    final batch = _firestore.batch();

    for (final student in students) {
      final isPresent = attendanceByStudentId[student.id] ?? false;
      final docId = '${dateString}_${student.id}';
      final ref = _firestore.collection(collection).doc(docId);
      final model = AttendanceModel(
        id: docId,
        studentId: student.id,
        studentName: student.name,
        stage: student.stage,
        stageNorm: normalizedStage,
        date: dateString,
        dayNameEnglish: english,
        dayNameArabic: arabic,
        isPresent: isPresent,
        updatedAt: DateTime.now(),
        updatedBy: cleanUpdatedBy,
      );
      batch.set(ref, model.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('[ATTENDANCE SAVE] Saved attendance for $dateString');
  }
}
