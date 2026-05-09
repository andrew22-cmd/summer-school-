import 'dart:async';

import 'package:flutter/material.dart';

import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/firestore_user_service.dart';

class AdminUsersProvider extends ChangeNotifier {
  AdminUsersProvider(this._firestoreUserService);

  final FirestoreUserService _firestoreUserService;

  List<UserModel> _users = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  StreamSubscription<List<UserModel>>? _usersSubscription;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void startListening() {
    _setLoading(true);
    _errorMessage = null;

    _usersSubscription?.cancel();
    _usersSubscription = _firestoreUserService.watchAllUsers().listen(
      (list) {
        _users = list;
        _setLoading(false);
      },
      onError: (error) {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _setLoading(false);
      },
    );
  }

  Future<void> addUser({
    required String name,
    required String phone,
    required String confessionFather,
    required UserRole role,
    required String stage,
    required String email,
    required String password,
  }) async {
    _setSaving(true);
    _errorMessage = null;

    try {
      // Create Firebase Auth account and Firestore user document together
      await _firestoreUserService.createUserWithAuth(
        email: email.trim(),
        password: password,
        name: name.trim(),
        phone: phone.trim(),
        confessionFather: confessionFather.trim(),
        role: role.value,
        stage: stage.trim(),
      );
      // Realtime listener will automatically update _users list
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> editUser({
    required String id,
    required String name,
    required String phone,
    required String confessionFather,
    required UserRole role,
    required String stage,
    required String email,
  }) async {
    _setSaving(true);
    _errorMessage = null;

    try {
      await _firestoreUserService.updateUser(id, {
        'name': name.trim(),
        'phone': phone.trim(),
        'confessionFather': confessionFather.trim(),
        'role': role.value,
        'stage': stage.trim(),
        'class': stage.trim(),
        'email': email.trim(),
      });
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> deleteUser(String id) async {
    _setSaving(true);
    _errorMessage = null;

    try {
      await _firestoreUserService.deleteUser(id);
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }
}
