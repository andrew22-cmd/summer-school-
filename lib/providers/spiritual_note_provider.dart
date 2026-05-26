import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:summerschool/models/spiritual_note_model.dart';
import 'package:summerschool/services/spiritual_note_service.dart';

class SpiritualNoteProvider extends ChangeNotifier {
  SpiritualNoteProvider(this._service);

  final SpiritualNoteService _service;

  List<SpiritualNoteModel> _notes = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<SpiritualNoteModel>>? _sub;
  String? _listeningUserId;

  List<SpiritualNoteModel> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> startListening(String userId) async {
    if (_listeningUserId == userId && _sub != null) return;

    _listeningUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _sub?.cancel();
    _sub = _service
        .watchNotesForUser(userId)
        .listen(
          (items) {
            debugPrint(
              '[SpiritualNoteProvider] firestore snapshots received userId=$userId count=${items.length}',
            );
            _notes = items;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> addNote({
    required String userId,
    required String userName,
    required String note,
    required String createdBy,
  }) async {
    await _service.addNote(
      userId: userId,
      userName: userName,
      note: note,
      createdBy: createdBy,
    );
  }

  Future<void> updateNote({required String id, required String note}) async {
    await _service.updateNote(id: id, note: note);
  }

  Future<void> deleteNote(String id) async {
    await _service.deleteNote(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
