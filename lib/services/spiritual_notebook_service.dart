import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/models/spiritual_notebook_model.dart';

class SpiritualNotebookService {
  SpiritualNotebookService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String collectionName = 'spiritual_notebook';

  String _docIdFor(String userId, String weekStartDate) =>
      '${userId}_$weekStartDate';

  Stream<SpiritualNotebookModel?> watchNotebook(
    String userId, {
    String? weekStartDate,
  }) {
    final wk = weekStartDate ?? _weekStartFor(DateTime.now());
    final docRef = _firestore
        .collection(collectionName)
        .doc(_docIdFor(userId, wk));
    return docRef.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null)
        return SpiritualNotebookModel.empty(userId: userId, weekStartDate: wk);
      final data = Map<String, dynamic>.from(snap.data()! as Map);
      return SpiritualNotebookModel.fromMap(data);
    });
  }

  Stream<SpiritualNotebookModel?> watchNotebookForUser(
    String userId, {
    String? weekStartDate,
  }) {
    return watchNotebook(userId, weekStartDate: weekStartDate);
  }

  Stream<List<UserModel>> watchMembersInStage(String stage) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.member.value)
        .where('stage', isEqualTo: stage.trim())
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
        );
  }

  Future<List<UserModel>> getMembersInStage(String stage) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.member.value)
        .where('stage', isEqualTo: stage.trim())
        .get();
    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> toggleCell(
    String userId,
    String weekStartDate,
    String dayKey,
    String fieldKey,
    bool value,
  ) async {
    final docId = _docIdFor(userId, weekStartDate);
    final docRef = _firestore.collection(collectionName).doc(docId);

    await docRef.set({
      'userId': userId,
      'weekStartDate': weekStartDate,
      'entries': {
        dayKey: {fieldKey: value},
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<SpiritualNotebookModel> getOrCreateNotebook(
    String userId, {
    String? weekStartDate,
  }) async {
    final wk = weekStartDate ?? _weekStartFor(DateTime.now());
    final docRef = _firestore
        .collection(collectionName)
        .doc(_docIdFor(userId, wk));
    final snap = await docRef.get();
    if (snap.exists && snap.data() != null) {
      return SpiritualNotebookModel.fromMap(snap.data()!);
    }

    final model = SpiritualNotebookModel.empty(
      userId: userId,
      weekStartDate: wk,
    );
    await docRef.set(model.toMap());
    return model;
  }

  String _weekStartFor(DateTime date) {
    // Week starts on Saturday
    final target = DateTime(date.year, date.month, date.day);
    final int saturday = DateTime.saturday; // 6
    int diff = target.weekday - saturday;
    if (diff < 0) diff += 7;
    final weekStart = target.subtract(Duration(days: diff));
    final iso = weekStart.toIso8601String().split('T').first;
    return iso;
  }
}
