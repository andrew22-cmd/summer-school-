import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/app_notification_model.dart';
import 'package:summerschool/models/notification_center_item_model.dart';
import 'package:summerschool/models/user_notification_model.dart';
import 'package:summerschool/models/user_model.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _userNotifications =>
      _firestore.collection('user_notifications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static String normalizeStage(String stage) =>
      stage.trim().replaceAll(' ', '').toLowerCase();

  Future<void> createNotification({
    required UserModel sender,
    required String title,
    required String body,
    required List<String> targetRoles,
    required List<String> targetStages,
    required bool isImportant,
  }) async {
    if (sender.role == UserRole.member) {
      throw Exception('غير مسموح لك بإرسال إشعارات.');
    }

    final normalizedRoles = targetRoles
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final normalizedStages = targetStages
        .map((e) => normalizeStage(e))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final effectiveRoles = sender.role == UserRole.memberManager
        ? <String>[UserRole.member.value]
        : normalizedRoles;
    final effectiveStages = sender.role == UserRole.memberManager
        ? <String>[normalizeStage(sender.stage)]
        : normalizedStages;

    final ref = _notifications.doc();
    final model = AppNotificationModel(
      id: ref.id,
      title: title.trim(),
      body: body.trim(),
      targetRoles: effectiveRoles,
      targetStages: effectiveStages,
      createdBy: sender.id,
      createdAt: DateTime.now(),
      isImportant: isImportant,
    );

    await ref.set(model.toMap());

    final recipientIds = await _resolveRecipientUserIds(
      sender: sender,
      targetRoles: effectiveRoles,
      targetStages: effectiveStages,
    );

    if (recipientIds.isEmpty) {
      debugPrint('[NotificationService] no recipients for id=${ref.id}');
      return;
    }

    final now = Timestamp.fromDate(DateTime.now());
    for (var i = 0; i < recipientIds.length; i += 400) {
      final chunk = recipientIds.skip(i).take(400);
      final batch = _firestore.batch();
      for (final userId in chunk) {
        final userRef = _userNotifications.doc();
        batch.set(userRef, {
          'id': userRef.id,
          'notificationId': ref.id,
          'userId': userId,
          'isRead': false,
          'createdAt': now,
        });
      }
      await batch.commit();
    }

    debugPrint(
      '[NotificationService] notification saved id=${ref.id} recipients=${recipientIds.length}',
    );
  }

  Future<List<String>> _resolveRecipientUserIds({
    required UserModel sender,
    required List<String> targetRoles,
    required List<String> targetStages,
  }) async {
    final usersSnap = await _users.get();
    final senderStage = normalizeStage(sender.stage);

    final recipients = <String>[];
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final uid = (data['id'] ?? doc.id).toString();
      if (uid.isEmpty) continue;

      final role = (data['role'] ?? '').toString().trim();
      final stage = normalizeStage((data['stage'] ?? '').toString());

      if (sender.role == UserRole.memberManager) {
        final allowed = role == UserRole.member.value && stage == senderStage;
        if (allowed) recipients.add(uid);
        continue;
      }

      final roleMatch = targetRoles.isEmpty || targetRoles.contains(role);
      final stageMatch = targetStages.isEmpty || targetStages.contains(stage);
      if (roleMatch && stageMatch) {
        recipients.add(uid);
      }
    }

    return recipients.toSet().toList();
  }

  Stream<List<String>> watchAvailableStages() {
    return _users.snapshots().map((snap) {
      final set = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final stage = (data['stage'] ?? '').toString().trim();
        if (stage.isNotEmpty) set.add(stage);
      }
      final list = set.toList()..sort();
      return list;
    });
  }

  Stream<List<UserNotificationModel>> watchUserNotifications(String userId) {
    return _userNotifications
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => UserNotificationModel.fromMap(doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<int> watchUnreadCount(String userId) {
    return _userNotifications
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) => snap.docs.where((doc) {
            final isRead = (doc.data()['isRead'] ?? false) == true;
            return !isRead;
          }).length,
        );
  }

  Stream<List<NotificationCenterItemModel>> watchNotificationCenter(
    String userId,
  ) {
    return watchUserNotifications(userId).asyncMap((userNotifs) async {
      final items = await Future.wait(
        userNotifs.map((userNotif) async {
          final notifDoc = await _notifications
              .doc(userNotif.notificationId)
              .get();
          final notifData = notifDoc.data();

          if (notifData == null) {
            return NotificationCenterItemModel(
              userNotificationId: userNotif.id,
              notificationId: userNotif.notificationId,
              title: 'إشعار',
              body: 'تم حذف هذا الإشعار.',
              createdAt: userNotif.createdAt,
              isRead: userNotif.isRead,
              isImportant: false,
            );
          }

          final notif = AppNotificationModel.fromMap(notifData);
          return NotificationCenterItemModel(
            userNotificationId: userNotif.id,
            notificationId: notif.id,
            title: notif.title,
            body: notif.body,
            createdAt: userNotif.createdAt,
            isRead: userNotif.isRead,
            isImportant: notif.isImportant,
          );
        }),
      );

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<void> markAsRead(String docId) async {
    await _userNotifications.doc(docId).set({
      'isRead': true,
    }, SetOptions(merge: true));
  }

  Future<void> markAllAsRead(String userId) async {
    final docs = await _userNotifications
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in docs.docs) {
      final isRead = (doc.data()['isRead'] ?? false) == true;
      if (isRead) continue;
      batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Create automatic notification for actions (tasks, attachments, events, etc.)
  /// This method automatically determines recipients based on sender role and scope
  Future<void> createAutomaticNotification({
    required UserModel sender,
    required String type, // task, attachment, event, schedule, visits
    required String title,
    required String body,
    String? targetUserId, // for tasks assigned to specific user
    List<String>? targetRoles, // for manager broadcasts
    List<String>? targetStages, // for stage-specific actions
    String? relatedId, // reference to task/attachment/event id
  }) async {
    try {
      if (sender.role == UserRole.member) {
        debugPrint(
          '[NotificationService] member cannot trigger automatic notifications',
        );
        return;
      }

      // Determine effective recipients based on sender role and targets
      final recipientIds = <String>{};

      if (targetUserId != null && targetUserId.isNotEmpty) {
        // Single user (task assigned to specific person)
        recipientIds.add(targetUserId);
      } else if (sender.role == UserRole.memberManager) {
        // Member manager can only notify their stage members
        final stageDocs = await _users
            .where('stage', isEqualTo: sender.stage)
            .where('role', isEqualTo: UserRole.member.value)
            .get();
        for (final doc in stageDocs.docs) {
          final uid = (doc.data()['id'] ?? doc.id).toString();
          if (uid.isNotEmpty) recipientIds.add(uid);
        }
      } else if (sender.role == UserRole.manager) {
        // Manager can target roles/stages or broadcast to all
        if ((targetRoles?.isEmpty ?? true) && (targetStages?.isEmpty ?? true)) {
          // Broadcast to everyone
          final allUsers = await _users.get();
          for (final doc in allUsers.docs) {
            final uid = (doc.data()['id'] ?? doc.id).toString();
            if (uid.isNotEmpty) recipientIds.add(uid);
          }
        } else {
          // Target specific roles and/or stages
          final query = _users.get();
          for (final doc in (await query).docs) {
            final data = doc.data();
            final uid = (data['id'] ?? doc.id).toString();
            final userRole = (data['role'] ?? '').toString().trim();
            final userStage = normalizeStage((data['stage'] ?? '').toString());

            if (uid.isEmpty) continue;

            final roleMatch =
                (targetRoles?.isEmpty ?? true) ||
                (targetRoles?.contains(userRole) ?? false);
            final stageMatch =
                (targetStages?.isEmpty ?? true) ||
                (targetStages?.contains(userStage) ?? false);

            if (roleMatch && stageMatch) {
              recipientIds.add(uid);
            }
          }
        }
      }

      if (recipientIds.isEmpty) {
        debugPrint(
          '[NotificationService] no recipients for automatic $type notification',
        );
        return;
      }

      // Create notification document
      final ref = _notifications.doc();
      final model = AppNotificationModel(
        id: ref.id,
        title: title.trim(),
        body: body.trim(),
        targetRoles: targetRoles ?? <String>[],
        targetStages: targetStages ?? <String>[],
        createdBy: sender.id,
        createdAt: DateTime.now(),
        isImportant: false,
        type: type,
        relatedId: relatedId ?? '',
      );

      await ref.set(model.toMap());

      // Create per-user notification entries
      final now = Timestamp.fromDate(DateTime.now());
      for (var i = 0; i < recipientIds.length; i += 400) {
        final chunk = recipientIds.skip(i).take(400).toList();
        final batch = _firestore.batch();
        for (final userId in chunk) {
          final userRef = _userNotifications.doc();
          batch.set(userRef, {
            'id': userRef.id,
            'notificationId': ref.id,
            'userId': userId,
            'isRead': false,
            'createdAt': now,
          });
        }
        await batch.commit();
      }

      debugPrint(
        '[NotificationService] automatic $type notification created id=${ref.id} recipients=${recipientIds.length}',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] error creating automatic notification: $e',
      );
      rethrow;
    }
  }
}
