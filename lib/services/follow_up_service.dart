import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/follow_up_model.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/class_member_service.dart';
import 'package:summerschool/services/notification_service.dart';

class FollowUpService {
  FollowUpService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _classMemberService = ClassMemberService(firestore: firestore),
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final ClassMemberService _classMemberService;
  final NotificationService _notificationService;

  static const String collection = 'visits';

  static String normalizeStage(String stage) =>
      stage.replaceAll(' ', '').toLowerCase();

  static DateTime monthStartOf(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime weekStartOf(DateTime date) => monthStartOf(date);

  static String monthKey(DateTime date) =>
      DateFormat('yyyyMM').format(monthStartOf(date));

  static String weekKey(DateTime date) => monthKey(date);

  static String monthLabel(DateTime date) =>
      DateFormat('MMMM yyyy').format(monthStartOf(date));

  static String dayName(DateTime date) {
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

  static bool _canManageAllStages(String requesterRole) =>
      requesterRole == 'manager';

  static bool _canAccessStage(
    String requesterRole,
    String requesterStage,
    String targetStage,
  ) {
    if (_canManageAllStages(requesterRole)) return true;
    final requesterNorm = normalizeStage(requesterStage);
    final targetNorm = normalizeStage(targetStage);
    return requesterNorm.isNotEmpty && requesterNorm == targetNorm;
  }

  static String visitTypeLabel(String value) {
    switch (value) {
      case 'phone':
        return 'Phone';
      case 'church':
        return 'Church';
      case 'home':
        return 'Home';
      case 'message':
        return 'Message';
      case 'other':
      default:
        return 'Other';
    }
  }

  Stream<List<ClassMemberModel>> watchStudentsForStage(
    String stage, {
    required String requesterRole,
    required String requesterStage,
  }) {
    final normalized = normalizeStage(stage);
    debugPrint(
      '[FollowUpService] watchStudentsForStage stage="$stage" stage_norm="$normalized" requesterRole=$requesterRole requesterStage="$requesterStage"',
    );

    if (normalized.isEmpty) {
      return Stream<List<ClassMemberModel>>.value(const []);
    }

    if (!_canAccessStage(requesterRole, requesterStage, stage)) {
      return Stream<List<ClassMemberModel>>.value(const []);
    }

    return _classMemberService.watchMembersForStage(stage);
  }

  Stream<List<ClassMemberModel>> watchChildrenForRequester({
    required String requesterRole,
    required String requesterStage,
  }) {
    if (_canManageAllStages(requesterRole)) {
      return _classMemberService.watchAllMembers();
    }
    if (requesterStage.trim().isEmpty) {
      return Stream<List<ClassMemberModel>>.value(const []);
    }
    return _classMemberService.watchMembersForStage(requesterStage);
  }

  Stream<List<FollowUpModel>> watchMonthlyVisitsForStage(
    String stage, {
    required String requesterRole,
    required String requesterStage,
    required DateTime monthDate,
  }) {
    final normalized = normalizeStage(stage);
    final monthStart = monthStartOf(monthDate);
    final month = monthStart.month;
    final year = monthStart.year;

    debugPrint(
      '[FollowUpService] watchMonthlyVisitsForStage stage="$stage" stage_norm="$normalized" month=${monthLabel(monthStart)} requesterRole=$requesterRole requesterStage="$requesterStage"',
    );

    if (normalized.isEmpty) {
      return Stream<List<FollowUpModel>>.value(const []);
    }

    if (!_canAccessStage(requesterRole, requesterStage, stage)) {
      return Stream<List<FollowUpModel>>.value(const []);
    }

    return _firestore.collection(collection).snapshots().map((snapshot) {
      final list =
          snapshot.docs
              .map((doc) => FollowUpModel.fromMap(doc.data(), doc.id))
              .where(
                (item) =>
                    normalizeStage(item.stage) == normalized &&
                    item.month == month &&
                    item.year == year,
              )
              .toList()
            ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

      debugPrint(
        '[FollowUpService] monthly visits snapshot docs=${list.length} stage_norm="$normalized" month=${monthLabel(monthStart)}',
      );

      return list;
    });
  }

  Stream<List<FollowUpModel>> watchVisitsForStudentMonth({
    required String studentId,
    required String stage,
    required String requesterRole,
    required String requesterStage,
    required DateTime monthDate,
  }) {
    final normalized = normalizeStage(stage);
    final monthStart = monthStartOf(monthDate);
    final month = monthStart.month;
    final year = monthStart.year;

    if (normalized.isEmpty ||
        !_canAccessStage(requesterRole, requesterStage, stage)) {
      return Stream<List<FollowUpModel>>.value(const []);
    }

    return _firestore.collection(collection).snapshots().map((snapshot) {
      final list =
          snapshot.docs
              .map((doc) => FollowUpModel.fromMap(doc.data(), doc.id))
              .where(
                (item) =>
                    item.studentId == studentId &&
                    normalizeStage(item.stage) == normalized &&
                    item.month == month &&
                    item.year == year,
              )
              .toList()
            ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

      return list;
    });
  }

  Stream<FollowUpModel?> watchLatestVisitForStudentMonth({
    required String studentId,
    required String stage,
    required String requesterRole,
    required String requesterStage,
    required DateTime monthDate,
  }) {
    return watchVisitsForStudentMonth(
      studentId: studentId,
      stage: stage,
      requesterRole: requesterRole,
      requesterStage: requesterStage,
      monthDate: monthDate,
    ).map((list) => list.isEmpty ? null : list.first);
  }

  Future<void> saveVisit({
    required String studentId,
    required String studentName,
    required String stage,
    required String servantId,
    required String servantName,
    required String createdByRole,
    required DateTime visitDate,
    required bool responded,
    required String visitType,
    required String summary,
    required String notes,
    required String favoriteThing,
    DateTime? nextFollowUp,
  }) async {
    final normalized = normalizeStage(stage);
    final now = DateTime.now();
    final monthStart = monthStartOf(visitDate);
    final docRef = _firestore.collection(collection).doc();

    final model = FollowUpModel(
      id: docRef.id,
      studentId: studentId,
      studentName: studentName,
      stage: stage,
      stageNorm: normalized,
      servantId: servantId,
      servantName: servantName,
      createdByRole: createdByRole,
      visitDate: visitDate,
      month: monthStart.month,
      year: monthStart.year,
      responded: responded,
      visitType: visitType,
      summary: summary.trim(),
      notes: notes.trim(),
      favoriteThing: favoriteThing.trim(),
      nextFollowUp: nextFollowUp,
      createdAt: now,
    );

    debugPrint(
      '[FollowUpService] saveVisit id=${docRef.id} student="$studentName" stage="$stage" visitDate=${DateFormat('yyyy-MM-dd').format(visitDate)} responded=$responded type=$visitType createdByRole=$createdByRole',
    );

    await docRef.set(model.toMap());

    await _notifyVisitCreated(
      createdByRole: createdByRole,
      servantId: servantId,
      studentName: studentName,
      stage: stage,
      visitId: docRef.id,
      visitType: visitType,
    );
  }

  Future<void> saveWeeklyFollowUp({
    required String studentId,
    required String studentName,
    required String stage,
    required String servantName,
    required bool contacted,
    required String notes,
    DateTime? weekStartDate,
    DateTime? now,
  }) async {
    await saveVisit(
      studentId: studentId,
      studentName: studentName,
      stage: stage,
      servantId: '',
      servantName: servantName,
      createdByRole: '',
      visitDate: weekStartDate ?? now ?? DateTime.now(),
      responded: contacted,
      visitType: 'other',
      summary: notes,
      notes: notes,
      favoriteThing: '',
      nextFollowUp: null,
    );
  }

  Stream<List<FollowUpModel>> watchWeeklyFollowUpsForStage(
    String stage,
    DateTime weekStartDate,
  ) {
    return watchMonthlyVisitsForStage(
      stage,
      requesterRole: 'manager',
      requesterStage: stage,
      monthDate: weekStartDate,
    );
  }

  Stream<FollowUpModel?> watchWeeklyFollowUpRecord({
    required String studentId,
    required String stage,
    required DateTime weekStartDate,
  }) {
    return watchLatestVisitForStudentMonth(
      studentId: studentId,
      stage: stage,
      requesterRole: 'manager',
      requesterStage: stage,
      monthDate: weekStartDate,
    );
  }

  Future<void> _notifyVisitCreated({
    required String createdByRole,
    required String servantId,
    required String studentName,
    required String stage,
    required String visitId,
    required String visitType,
  }) async {
    final role = createdByRole.trim().toLowerCase();
    if (role != UserRole.member.value) {
      return;
    }

    try {
      final sender = await _loadUserById(servantId);
      if (sender == null) {
        debugPrint(
          '[FollowUpService] visit notify skipped, sender not found servantId=$servantId',
        );
        return;
      }

      final stageNorm = normalizeStage(stage);
      debugPrint(
        '[FollowUpService] visit notify start visitId=$visitId stage=$stageNorm sender=${sender.id}',
      );

      await _notificationService.createAutomaticNotification(
        sender: sender,
        type: 'visit',
        title: 'New Visit',
        body: 'A new visit was recorded for student $studentName',
        targetRoles: <String>[UserRole.memberManager.value],
        targetStages: <String>[stageNorm],
        relatedId: visitId,
      );

      debugPrint(
        '[FollowUpService] visit notify done visitId=$visitId type=$visitType stage=$stageNorm',
      );
    } catch (e) {
      debugPrint('[FollowUpService] visit notify error: $e');
    }
  }

  Future<UserModel?> _loadUserById(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;

    final doc = await _firestore.collection('users').doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserModel.fromMap(doc.data()!);
  }
} /*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/follow_up_model.dart';
import 'package:summerschool/services/class_member_service.dart';

class FollowUpService {
  FollowUpService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _classMemberService = ClassMemberService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ClassMemberService _classMemberService;

  static const String collection = 'followups';

  static String normalizeStage(String stage) =>
      stage.replaceAll(' ', '').toLowerCase();

  static DateTime weekStartOf(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static String weekKey(DateTime date) =>
      DateFormat('yyyyMMdd').format(weekStartOf(date));

  static String dayName(DateTime date) {
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

  static String buildDocumentId(String studentId, DateTime weekStartDate) {
    return '${studentId.trim()}_${weekKey(weekStartDate)}';
  }

  Stream<List<ClassMemberModel>> watchStudentsForStage(String stage) {
    final normalized = normalizeStage(stage);
    debugPrint(
      '[FollowUpService] watchStudentsForStage stage="$stage" stage_norm="$normalized"',
    );

    if (normalized.isEmpty) {
      return Stream<List<ClassMemberModel>>.value(const []);
    }

    return _classMemberService.watchMembersForStage(stage);
  }

  Stream<List<FollowUpModel>> watchWeeklyFollowUpsForStage(
    String stage,
    DateTime weekStartDate,
  ) {
    final normalized = normalizeStage(stage);
    final weekStart = weekStartOf(weekStartDate);

    debugPrint(
      '[FollowUpService] watchWeeklyFollowUpsForStage stage="$stage" stage_norm="$normalized" weekStart=${DateFormat('yyyy-MM-dd').format(weekStart)}',
    );

    if (normalized.isEmpty) {
      return Stream<List<FollowUpModel>>.value(const []);
    }

    // Listen to entire collection and filter stage_norm + weekStart in-memory.
    // This avoids any Firestore composite index requirements.
    return _firestore.collection(collection).snapshots().map((snapshot) {
      final list =
          snapshot.docs
              .map((doc) => FollowUpModel.fromMap(doc.data(), doc.id))
              .where(
                (item) =>
                    normalizeStage(item.stage) == normalized &&
                    weekStartOf(item.weekStartDate) == weekStart,
              )
              .toList()
            ..sort((a, b) => a.studentName.compareTo(b.studentName));

      debugPrint(
        '[FollowUpService] weekly followups snapshot docs=${list.length} stage_norm="$normalized" weekKey=${weekKey(weekStart)}',
      );

      return list;
    });
  }

  Stream<FollowUpModel?> watchWeeklyFollowUpRecord({
    required String studentId,
    required String stage,
    required DateTime weekStartDate,
  }) {
    final normalized = normalizeStage(stage);
    final weekStart = weekStartOf(weekStartDate);
    final docId = buildDocumentId(studentId, weekStart);

    debugPrint(
      '[FollowUpService] watchWeeklyFollowUpRecord studentId=$studentId stage_norm="$normalized" weekKey=${weekKey(weekStart)}',
    );

    if (normalized.isEmpty) {
      return Stream<FollowUpModel?>.value(null);
    }

    return _firestore.collection(collection).doc(docId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FollowUpModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> saveWeeklyFollowUp({
    required String studentId,
    required String studentName,
    required String stage,
    required String servantName,
    required bool contacted,
    required String notes,
    DateTime? weekStartDate,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final weekStart = weekStartOf(weekStartDate ?? current);
    final normalized = normalizeStage(stage);
    final docId = buildDocumentId(studentId, weekStart);
    final ref = _firestore.collection(collection).doc(docId);

    DateTime createdAt = current;
    final existing = await ref.get();
    if (existing.exists && existing.data() != null) {
      final old = FollowUpModel.fromMap(existing.data()!, existing.id);
      createdAt = old.createdAt;
    }

    final model = FollowUpModel(
      id: docId,
      studentId: studentId,
      studentName: studentName,
      stage: stage,
      stage_norm: normalized,
      servantName: servantName,
      weekStartDate: weekStart,
      currentDate: DateFormat('yyyy/MM/dd').format(current),
      dayName: dayName(current),
      contacted: contacted,
      notes: notes.trim(),
      createdAt: createdAt,
      updatedAt: current,
    );

    debugPrint(
      '[FollowUpService] saveWeeklyFollowUp id=$docId student="$studentName" stage="$stage" contacted=$contacted',
    );

    await ref.set(model.toMap());
  }
}
*/
