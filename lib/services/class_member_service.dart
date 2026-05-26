import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:summerschool/models/class_member_model.dart';

class ClassMemberService {
  ClassMemberService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String collection = 'class_members';

  String _docId() => _firestore.collection(collection).doc().id;

  /// Normalize a stage string for indexed queries.
  /// Example: '2 M' -> '2m', '2M' -> '2m'
  static String normalizeStage(String stage) =>
      stage.replaceAll(' ', '').toLowerCase();

  void _logQuery({required String source, String? stage}) {
    final normalized = stage == null ? '' : normalizeStage(stage);
    debugPrint(
      '[ClassMemberService][$source] collection=$collection '
      'query=stage_norm=="$normalized" OR fallback stage variants'
      '${stage == null ? '' : ' (currentStage="$stage")'}',
    );
  }

  void _logMember(String source, ClassMemberModel member) {
    debugPrint(
      '[ClassMemberService][$source] member name="${member.name}" stage="${member.stage}" stage_norm="${normalizeStage(member.stage)}" points=${member.totalPoints}',
    );
  }

  /// Stream all members (admin view). Use server-side queries for stage-specific
  /// views via [watchMembersForStage].
  Stream<List<ClassMemberModel>> watchAllMembers() {
    debugPrint('[ClassMemberService][watchAllMembers] query=orderBy(name)');
    return _firestore.collection(collection).orderBy('name').snapshots().map((
      snap,
    ) {
      debugPrint(
        '[ClassMemberService][watchAllMembers] snapshot docs=${snap.docs.length}',
      );
      final list = snap.docs
          .map((d) => ClassMemberModel.fromMap(d.data()))
          .toList();
      for (final m in list) {
        _logMember('watchAllMembers', m);
      }
      return list;
    });
  }

  Future<List<ClassMemberModel>> getAllMembers() async {
    debugPrint('[ClassMemberService][getAllMembers] query=orderBy(name)');
    final snap = await _firestore.collection(collection).orderBy('name').get();
    final list = snap.docs
        .map((d) => ClassMemberModel.fromMap(d.data()))
        .toList();
    for (final m in list) {
      _logMember('getAllMembers', m);
    }
    return list;
  }

  /// Real-time stream for members of a specific stage.
  /// Primary query uses indexed `stage_norm`. A fallback query on `stage`
  /// (space/no-space and case variants) is merged to maintain compatibility
  /// with old records until migration completes.
  Stream<List<ClassMemberModel>> watchMembersForStage(String stage) {
    final normalized = normalizeStage(stage);
    if (normalized.isEmpty) {
      debugPrint(
        '[ClassMemberService][watchMembersForStage] empty stage received. Returning empty stream without querying Firestore.',
      );
      return Stream<List<ClassMemberModel>>.value(const []);
    }
    _logQuery(source: 'watchMembersForStage', stage: stage);

    final qPrimary = _firestore
        .collection(collection)
        .where('stage_norm', isEqualTo: normalized);

    // fallback candidates
    final noSpace = normalized;
    final withSpace = noSpace.length >= 2
        ? '${noSpace[0]} ${noSpace.substring(1)}'
        : noSpace;
    final candidates = <String>{
      noSpace,
      noSpace.toUpperCase(),
      withSpace,
      withSpace.toUpperCase(),
    }..removeWhere((s) => s.isEmpty);

    final qFallback = candidates.isEmpty
        ? null
        : _firestore
              .collection(collection)
              .where('stage', whereIn: candidates.toList());

    final controller = StreamController<List<ClassMemberModel>>.broadcast();

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subPrimary;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subFallback;
    List<DocumentSnapshot<Map<String, dynamic>>> lastPrimary = [];
    List<DocumentSnapshot<Map<String, dynamic>>> lastFallback = [];

    void emitMerged() {
      final map = <String, ClassMemberModel>{};
      for (final d in lastPrimary) {
        final m = ClassMemberModel.fromMap(d.data()!);
        map[m.id] = m;
      }
      for (final d in lastFallback) {
        final m = ClassMemberModel.fromMap(d.data()!);
        map[m.id] = m;
      }
      final list = map.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      debugPrint(
        '[STREAM] watchMembersForStage emitted count=${list.length} stage_norm="$normalized"',
      );
      for (final m in list) {
        debugPrint(
          '[STREAM] member name="${m.name}" totalPoints=${m.totalPoints}',
        );
      }
      controller.add(list);
    }

    controller.onListen = () {
      debugPrint(
        '[ClassMemberService][watchMembersForStage] primary=query stage_norm=="$normalized" orderBy(name)',
      );
      subPrimary = qPrimary.snapshots().listen((snap) {
        debugPrint(
          '[STREAM] watchMembersForStage primary snapshot received docs=${snap.docs.length}',
        );
        lastPrimary = snap.docs
            .cast<DocumentSnapshot<Map<String, dynamic>>>()
            .toList();
        emitMerged();
      }, onError: (e, st) => controller.addError(e, st));

      if (qFallback != null) {
        debugPrint(
          '[ClassMemberService][watchMembersForStage] fallback=query stage in ${candidates.toList()} orderBy(name)',
        );
        subFallback = qFallback.snapshots().listen((snap) {
          debugPrint(
            '[STREAM] watchMembersForStage fallback snapshot received docs=${snap.docs.length}',
          );
          lastFallback = snap.docs
              .cast<DocumentSnapshot<Map<String, dynamic>>>()
              .toList();
          emitMerged();
        }, onError: (e, st) => controller.addError(e, st));
      }
    };

    controller.onCancel = () async {
      await subPrimary?.cancel();
      await subFallback?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<List<ClassMemberModel>> getMembersForStage(String stage) async {
    final normalized = normalizeStage(stage);
    if (normalized.isEmpty) {
      debugPrint(
        '[ClassMemberService][getMembersForStage] empty stage received. Returning empty list without querying Firestore.',
      );
      return const [];
    }
    _logQuery(source: 'getMembersForStage', stage: stage);

    final primarySnap = await _firestore
        .collection(collection)
        .where('stage_norm', isEqualTo: normalized)
        .orderBy('name')
        .get();
    var list = primarySnap.docs
        .map((d) => ClassMemberModel.fromMap(d.data()))
        .toList();
    debugPrint(
      '[ClassMemberService][getMembersForStage] primary docs=${list.length}',
    );
    for (final m in list) {
      _logMember('getMembersForStage:primary', m);
    }
    if (list.isNotEmpty) return list;

    final noSpace = normalized;
    final withSpace = noSpace.length >= 2
        ? '${noSpace[0]} ${noSpace.substring(1)}'
        : noSpace;
    final candidates = <String>{
      noSpace,
      noSpace.toUpperCase(),
      withSpace,
      withSpace.toUpperCase(),
    }..removeWhere((s) => s.isEmpty);

    if (candidates.isNotEmpty) {
      debugPrint(
        '[ClassMemberService][getMembersForStage] fallback candidates=${candidates.toList()}',
      );
      final fallbackSnap = await _firestore
          .collection(collection)
          .where('stage', whereIn: candidates.toList())
          .orderBy('name')
          .get();
      list = fallbackSnap.docs
          .map((d) => ClassMemberModel.fromMap(d.data()))
          .toList();
      debugPrint(
        '[ClassMemberService][getMembersForStage] fallback docs=${list.length}',
      );
      for (final m in list) {
        _logMember('getMembersForStage:fallback', m);
      }
    }

    return list;
  }

  Future<ClassMemberModel> addMember(ClassMemberModel member) async {
    final id = _docId();
    final docRef = _firestore.collection(collection).doc(id);
    final toSave = member.toMap()..['id'] = id;
    // ensure stage_norm exists for indexed queries
    toSave['stage_norm'] = normalizeStage((toSave['stage'] ?? '').toString());
    debugPrint(
      '[ClassMemberService][addMember] save name="${member.name}" stage="${member.stage}" stage_norm="${toSave['stage_norm']}"',
    );
    await docRef.set(toSave);
    return ClassMemberModel.fromMap(toSave);
  }

  Future<void> updateMember(String id, Map<String, dynamic> updates) async {
    final docRef = _firestore.collection(collection).doc(id);
    final Map<String, dynamic> toUpdate = Map.from(updates);
    if (toUpdate.containsKey('stage')) {
      toUpdate['stage_norm'] = normalizeStage(
        (toUpdate['stage'] ?? '').toString(),
      );
    }
    debugPrint(
      '[ClassMemberService][updateMember] id=$id stage="${toUpdate['stage']}" stage_norm="${toUpdate['stage_norm']}"',
    );
    await docRef.update(toUpdate);
  }

  Future<void> deleteMember(String id) async {
    final docRef = _firestore.collection(collection).doc(id);
    await docRef.delete();
  }

  /// One-time migration utility: ensure all documents have `stage_norm` field.
  /// Returns number of documents updated.
  Future<int> migrateAddStageNormAll() async {
    final col = _firestore.collection(collection);
    final snap = await col.get();
    if (snap.docs.isEmpty) return 0;

    int updated = 0;
    final batch = _firestore.batch();
    int ops = 0;
    const int batchSize = 450; // keep below limits

    for (final doc in snap.docs) {
      final data = doc.data();
      final stage = (data['stage'] ?? '').toString();
      final norm = normalizeStage(stage);
      final existing = (data['stage_norm'] ?? '').toString();
      if (existing != norm) {
        batch.update(col.doc(doc.id), {'stage_norm': norm});
        ops++;
        updated++;
      }
      if (ops >= batchSize) {
        await batch.commit();
        ops = 0;
      }
    }

    if (ops > 0) await batch.commit();
    return updated;
  }
}
