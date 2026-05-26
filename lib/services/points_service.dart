import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/student_points_record_model.dart';
import 'package:summerschool/services/class_member_service.dart';

/// ╔═══════════════════════════════════════════════════════════════════╗
/// ║            POINTS SERVICE - FIRESTORE INTEGRATION                ║
/// ╚═══════════════════════════════════════════════════════════════════╝
///
/// CRITICAL IMPLEMENTATION NOTES:
///
/// 1. ATOMIC TRANSACTIONS:
///    - addPoints() and removePoints() use Firestore transactions
///    - Both totalPoints update AND history creation MUST succeed together
///    - If either fails, the entire transaction rolls back
///
/// 2. REALTIME UPDATES:
///    - watchStudentsForStage() uses snapshots() for realtime updates
///    - watchHistoryForStage() uses snapshots() for realtime updates
///    - Provider listeners automatically refresh when Firestore data changes
///
/// 3. DEBUG LOGGING:
///    - Look for logs starting with "[FIRESTORE_WRITE]"
///    - Each operation prints: before/after values, status, and errors
///    - Check "╔════" boxes in console for operation summaries
///
/// 4. TROUBLESHOOTING:
///    If points don't update:
///      → Check debug logs for "[FIRESTORE_WRITE]" errors
///      → Look for "permission denied" messages
///      → Verify class_members document exists in Firestore
///      → Verify totalPoints field is initialized (not missing)
///
///    If history is empty:
///      → Check Firestore Console: collections → student_points_records
///      → Verify history documents are being created
///      → Check Provider logs for stream emissions
///      → Look for "[READ] HIST" logs showing query results
///
///    If UI doesn't update after write:
///      → Check Provider logs for "[notifyListeners()]"
///      → Verify stream listeners are attached
///      → Check for stream errors in Provider logs
///
/// 5. REQUIRED FIRESTORE SECURITY RULES:
///    - class_members: allow update for authenticated users
///    - student_points_records: allow create for authenticated users
///    - Both collections: allow read based on stage filtering
///
class PointsService {
  PointsService({
    FirebaseFirestore? firestore,
    ClassMemberService? classMemberService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _classMemberService =
           classMemberService ?? ClassMemberService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ClassMemberService _classMemberService;

  static const String _historyCollection = 'student_points_records';
  static String normalizeStage(String stage) =>
      ClassMemberService.normalizeStage(stage);

  Stream<List<ClassMemberModel>> watchStudentsForStage(String stage) {
    return _classMemberService.watchMembersForStage(stage);
  }

  Future<List<ClassMemberModel>> getStudentsForStage(String stage) {
    return _classMemberService.getMembersForStage(stage);
  }

  Stream<List<StudentPointsRecordModel>> watchHistoryForStage(
    String stage, {
    String? studentId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_historyCollection)
        .where('stage_norm', isEqualTo: normalizeStage(stage));

    return query.snapshots().map((snap) {
      debugPrint(
        '[STREAM] watchHistoryForStage snapshot received docs=${snap.docs.length}',
      );
      final list =
          snap.docs
              .map((d) {
                final model = StudentPointsRecordModel.fromMap(d.data());
                debugPrint(
                  '[STREAM] record entry operationType="${model.operationType}" points=${model.points} totalPointsAfter=${model.totalPointsAfter}',
                );
                return model;
              })
              .where((model) {
                final filterId = studentId?.trim() ?? '';
                return filterId.isEmpty || model.studentId == filterId;
              })
              .whereType<StudentPointsRecordModel>()
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint(
        '[STREAM] watchHistoryForStage filtered result count=${list.length} studentId="${studentId ?? 'ALL'}"',
      );
      return list;
    });
  }

  Future<void> addPoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdByUserId,
    required String createdByName,
  }) {
    return _applyPoints(
      student: student,
      points: points,
      reason: reason,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      isAdd: true,
    );
  }

  Future<void> removePoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdByUserId,
    required String createdByName,
  }) {
    return _applyPoints(
      student: student,
      points: points,
      reason: reason,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      isAdd: false,
    );
  }

  Future<void> _applyPoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdByUserId,
    required String createdByName,
    required bool isAdd,
  }) async {
    final cleanReason = reason.trim();
    final cleanCreatedByUserId = createdByUserId.trim().isEmpty
        ? 'local_admin'
        : createdByUserId.trim();
    final cleanCreatedByName = createdByName.trim().isEmpty
        ? cleanCreatedByUserId
        : createdByName.trim();

    if (points <= 0) {
      throw Exception('Points must be greater than zero.');
    }
    if (cleanReason.isEmpty) {
      throw Exception('Reason is required.');
    }

    debugPrint('[FIRESTORE_WRITE] Starting ${isAdd ? 'ADD' : 'REMOVE'} points');
    debugPrint('[FIRESTORE_WRITE] studentId=${student.id}');
    debugPrint('[FIRESTORE_WRITE] studentName=${student.name}');
    debugPrint('[FIRESTORE_WRITE] stage=${student.stage}');
    debugPrint('[FIRESTORE_WRITE] points=$points reason=$cleanReason');
    debugPrint('[FIRESTORE_WRITE] createdByUserId=$cleanCreatedByUserId');
    debugPrint('[FIRESTORE_WRITE] createdByName=$cleanCreatedByName');

    final memberRef = _firestore.collection('class_members').doc(student.id);
    final historyRef = _firestore.collection(_historyCollection).doc();

    try {
      debugPrint('[TRANSACTION] Starting atomic Firestore transaction');
      int oldPoints = 0;
      int newPoints = 0;

      await _firestore.runTransaction((tx) async {
        debugPrint('[TRANSACTION] Inside transaction block');

        debugPrint('[READ] Fetching class_members/${student.id}');
        final memberSnap = await tx.get(memberRef);

        if (!memberSnap.exists) {
          debugPrint('[ERROR] Student document does not exist in Firestore');
          debugPrint('[ERROR] path=class_members/${student.id}');
          throw Exception(
            'Student document not found. Please add them to class first.',
          );
        }

        final data = memberSnap.data() ?? <String, dynamic>{};
        debugPrint('[READ] Document found. Fields: ${data.keys.join(", ")}');

        oldPoints = (data['totalPoints'] ?? 0) is int
            ? (data['totalPoints'] ?? 0) as int
            : int.tryParse((data['totalPoints'] ?? '0').toString()) ?? 0;

        debugPrint(
          '[VALUE] old totalPoints=$oldPoints type=${data['totalPoints'].runtimeType}',
        );

        newPoints = isAdd ? oldPoints + points : oldPoints - points;
        debugPrint(
          '[CALC] $oldPoints ${isAdd ? '+' : '-'} $points = $newPoints',
        );

        if (newPoints < 0) {
          debugPrint(
            '[ERROR] Cannot remove points: would be negative ($newPoints)',
          );
          throw Exception('Insufficient points to remove.');
        }

        debugPrint('[UPDATE] Updating class_members/${student.id}');
        tx.update(memberRef, {
          'totalPoints': newPoints,
          'updatedAt': DateTime.now(),
        });
        debugPrint('[UPDATE] queued totalPoints=$newPoints');

        debugPrint('[CREATE] Creating student_points_records/${historyRef.id}');
        final historyData = {
          'id': historyRef.id,
          'studentId': student.id,
          'studentName': student.name,
          'stage': student.stage,
          'stage_norm': normalizeStage(student.stage),
          'operationType': isAdd ? 'add' : 'remove',
          'points': points,
          'reason': cleanReason,
          'createdByUserId': cleanCreatedByUserId,
          'createdByName': cleanCreatedByName,
          'createdAt': DateTime.now(),
          'totalPointsBefore': oldPoints,
          'totalPointsAfter': newPoints,
        };
        tx.set(historyRef, historyData);
        debugPrint('[CREATE] queued history document id=${historyRef.id}');
        debugPrint('[CREATE] totalPointsBefore=$oldPoints');
        debugPrint('[CREATE] totalPointsAfter=$newPoints');
      });

      debugPrint('[COMMIT] Transaction committed successfully');
      debugPrint('[RESULT] $oldPoints -> $newPoints');
      debugPrint('[VERIFY] historyId=${historyRef.id}');
    } catch (e, st) {
      debugPrint('[ERROR] Transaction failed');
      debugPrint('[ERROR] exception=$e');
      debugPrint('[ERROR] type=${e.runtimeType}');
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        debugPrint('[ERROR] Firestore permission denied');
        debugPrint(
          '[ERROR] Check rules for class_members update and student_points_records create',
        );
      }
      debugPrint('[STACK] $st');
      rethrow;
    }
  }

  Future<int> cleanupHistoryOlderThan(Duration age) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(age));
    final historyCol = _firestore.collection(_historyCollection);
    final snap = await historyCol.where('createdAt', isLessThan: cutoff).get();
    if (snap.docs.isEmpty) return 0;

    var deleted = 0;
    const batchSize = 450;
    final docs = snap.docs;

    for (var i = 0; i < docs.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
      for (final doc in docs.sublist(i, end)) {
        batch.delete(doc.reference);
        deleted++;
      }
      await batch.commit();
    }

    return deleted;
  }
}
