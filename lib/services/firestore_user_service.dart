import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/user_model.dart';

class FirestoreUserService {
  FirestoreUserService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  String generateUserId() => _usersCollection.doc().id;

  /// Creates a Firebase Authentication account and Firestore user document.
  /// For admin-created users only.
  /// Keeps the current user session by reloading after account creation.
  Future<UserModel> createUserWithAuth({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String confessionFather,
    required String role,
    required String stage,
  }) async {
    // Store current admin session to restore later
    final currentUser = _firebaseAuth.currentUser;

    try {
      // 1. Create Firebase Auth account
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUserId = userCredential.user?.uid;
      if (newUserId == null) {
        throw Exception(
          'Failed to create authentication account: No UID returned.',
        );
      }

      // 2. Create Firestore user document with uid
      final userRole = _parseUserRole(role);
      final newUser = UserModel(
        id: newUserId,
        name: name.trim(),
        phone: phone.trim(),
        confessionFather: confessionFather.trim(),
        role: userRole,
        stage: stage.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );

      await _usersCollection.doc(newUserId).set(newUser.toMap());

      // 3. Restore admin session if one existed
      if (currentUser != null) {
        try {
          // Reload to restore admin session from Firebase session persistence
          await _firebaseAuth.currentUser?.reload();
        } catch (e) {
          debugPrint(
            'Warning: Could not reload admin session after user creation: $e',
          );
        }
      }

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('create user with auth', e));
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'operation-not-allowed':
        return 'User account creation is disabled.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  UserRole _parseUserRole(String roleStr) {
    final normalized = roleStr.toLowerCase();
    if (normalized.contains('member_manager') ||
        normalized.contains('membermanager')) {
      return UserRole.memberManager;
    } else if (normalized.contains('manager')) {
      return UserRole.manager;
    }
    return UserRole.member;
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toMap());
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('create user', e));
    }
  }

  Future<UserModel?> getUser(String id) async {
    try {
      final doc = await _usersCollection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('get user', e));
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('stage')) {
        final stage = (data['stage'] ?? '').toString();
        data['stage_norm'] = stage.replaceAll(' ', '').toLowerCase();
      } else if (data.containsKey('class')) {
        final stage = (data['class'] ?? '').toString();
        data['stage_norm'] = stage.replaceAll(' ', '').toLowerCase();
      }
      await _usersCollection.doc(id).update(data);
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('update user', e));
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _usersCollection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('delete user', e));
    }
  }

  /// Fetches the first [limit] users ordered by creation date.
  /// For screens that need the complete list (e.g. small orgs), keep limit
  /// at a safe value. Increases reads logarithmically, not unboundedly.
  Future<List<UserModel>> getAllUsers({int limit = 1000}) async {
    try {
      final snapshot = await _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .where((doc) => doc.data().isNotEmpty)
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('list users', e));
    }
  }

  /// Cursor-based paginated fetch for infinite-scroll UIs.
  /// Pass [lastDocument] from the previous page's last snapshot to load next.
  Future<({List<UserModel> users, DocumentSnapshot? lastDocument})>
  getUsersPage({DocumentSnapshot? lastDocument, int limit = 30}) async {
    try {
      Query<Map<String, dynamic>> query = _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final users = snapshot.docs
          .where((doc) => doc.data().isNotEmpty)
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();

      final last = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return (users: users, lastDocument: last);
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('paginate users', e));
    }
  }

  /// Real-time stream capped at [limit] documents.
  /// For admin dashboards; increase limit only when operationally justified.
  Stream<List<UserModel>> watchAllUsers({int limit = 1000}) {
    try {
      return _usersCollection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .where((doc) => doc.data().isNotEmpty)
                .map((doc) => UserModel.fromMap(doc.data()))
                .toList(),
          );
    } on FirebaseException catch (e) {
      throw Exception(_firebaseMessage('watch users', e));
    }
  }

  String _firebaseMessage(String action, FirebaseException e) {
    final code = e.code.isNotEmpty ? ' (${e.code})' : '';
    final message = e.message ?? 'Unknown Firebase error.';
    return 'Failed to $action$code: $message';
  }
}
