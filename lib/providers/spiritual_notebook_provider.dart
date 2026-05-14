import 'dart:async';

import 'package:flutter/material.dart';
import 'package:summerschool/models/spiritual_notebook_model.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';

class SpiritualNotebookProvider extends ChangeNotifier {
  SpiritualNotebookProvider(this._service);

  final SpiritualNotebookService _service;

  SpiritualNotebookModel? _notebook;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<SpiritualNotebookModel?>? _sub;

  SpiritualNotebookModel? get notebook => _notebook;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> startListening({
    required String userId,
    String? weekStartDate,
  }) async {
    _setLoading(true);
    _sub?.cancel();
    _sub = _service
        .watchNotebook(userId, weekStartDate: weekStartDate)
        .listen(
          (model) {
            _notebook = model;
            _setLoading(false);
            notifyListeners();
          },
          onError: (err) {
            _error = err.toString();
            _setLoading(false);
            notifyListeners();
          },
        );
  }

  Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> toggleCell({
    required String userId,
    required String weekStartDate,
    required String dayKey,
    required String fieldKey,
  }) async {
    if (_notebook == null) return;
    final current = _notebook!.entries[dayKey]?[fieldKey] == true;
    // Optimistic update
    _notebook!.entries[dayKey]?[fieldKey] = !current;
    notifyListeners();

    try {
      await _service.toggleCell(
        userId,
        weekStartDate,
        dayKey,
        fieldKey,
        !current,
      );
    } catch (e) {
      // revert on error
      _notebook!.entries[dayKey]?[fieldKey] = current;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
