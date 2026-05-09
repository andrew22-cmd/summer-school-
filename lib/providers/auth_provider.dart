import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/firestore_user_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? firebaseAuth,
    FirestoreUserService? firestoreUserService,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestoreUserService = firestoreUserService ?? FirestoreUserService();

  final FirebaseAuth _firebaseAuth;
  final FirestoreUserService _firestoreUserService;

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;

  bool get isManager => _user?.role == UserRole.manager;
  bool get isMemberManager => _user?.role == UserRole.memberManager;
  bool get isMember => _user?.role == UserRole.member;

  Future<void> initialize() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        _user = null;
        return;
      }

      _user = await _fetchOrCreateFirestoreUser(firebaseUser);
    } on FirebaseAuthException catch (error) {
      _errorMessage = _authErrorMessage(error);
      _user = null;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      _user = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Login failed: No user returned from Firebase.');
      }

      _user = await _fetchOrCreateFirestoreUser(firebaseUser);
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _authErrorMessage(error);
      return false;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _authErrorMessage(error);
      return false;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firebaseAuth.signOut();
      _user = null;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<UserModel> _fetchOrCreateFirestoreUser(User firebaseUser) async {
    final existingUser = await _firestoreUserService.getUser(firebaseUser.uid);
    if (existingUser != null) {
      return existingUser;
    }

    final generatedName = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!.trim()
        : _fallbackNameFromEmail(firebaseUser.email);

    final newUser = UserModel(
      id: firebaseUser.uid,
      name: generatedName,
      phone: firebaseUser.phoneNumber ?? '',
      confessionFather: '',
      role: UserRole.member,
      stage: '',
      email: firebaseUser.email?.trim() ?? '',
      createdAt: DateTime.now(),
    );

    await _firestoreUserService.createUser(newUser);
    return newUser;
  }

  String _fallbackNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'New User';
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'New User';
    return localPart;
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
}
