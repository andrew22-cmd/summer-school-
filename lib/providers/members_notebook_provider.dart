import 'dart:async';

import 'package:flutter/material.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';

class MembersNotebookProvider extends ChangeNotifier {
  MembersNotebookProvider(this._service);

  final SpiritualNotebookService _service;

  StreamSubscription<List<UserModel>>? _sub;
  List<UserModel> _members = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<UserModel> get members {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _members;
    return _members.where((m) {
      return m.name.toLowerCase().contains(query) ||
          m.stage.toLowerCase().contains(query) ||
          m.className.toLowerCase().contains(query);
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  Future<void> startListening({required String stage}) async {
    _setLoading(true);
    await _sub?.cancel();
    _sub = _service
        .watchMembersInStage(stage)
        .listen(
          (members) {
            _members = members;
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

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
