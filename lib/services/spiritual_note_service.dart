import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/models/spiritual_note_model.dart';

class SpiritualNoteService {
  SpiritualNoteService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'spiritual_notes';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(collection);

  Stream<List<SpiritualNoteModel>> watchNotesForUser(String userId) {
    return _col.snapshots().map((snapshot) {
      debugPrint(
        '[SpiritualNoteService] firestore snapshots received docs=${snapshot.docs.length}',
      );
      final items =
          snapshot.docs
              .where((d) => d.data().isNotEmpty)
              .map((d) => SpiritualNoteModel.fromMap(d.data()))
              .where((n) => n.userId == userId)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<void> addNote({
    required String userId,
    required String userName,
    required String note,
    required String createdBy,
  }) async {
    final id = _col.doc().id;
    debugPrint(
      '[SpiritualNoteService] add note userId=$userId userName="$userName"',
    );
    await _col.doc(id).set({
      'id': id,
      'userId': userId,
      'userName': userName,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });
  }

  Future<void> updateNote({required String id, required String note}) async {
    debugPrint('[SpiritualNoteService] update note id=$id');
    await _col.doc(id).update({
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String id) async {
    debugPrint('[SpiritualNoteService] delete note id=$id');
    await _col.doc(id).delete();
  }
}
