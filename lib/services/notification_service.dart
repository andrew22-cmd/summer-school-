import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/app_notification_model.dart';
import 'package:summerschool/models/notification_center_item_model.dart';
import 'package:summerschool/models/user_notification_model.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/github_trigger_service.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    GitHubTriggerService? githubTriggerService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _githubTriggerService = githubTriggerService ?? GitHubTriggerService();

  final FirebaseFirestore _firestore;
  final GitHubTriggerService _githubTriggerService;

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
      senderId: sender.id,
      isRead: false,
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

    await _dispatchPushNotification(
      sender: sender,
      title: title,
      body: body,
      recipientIds: recipientIds.toSet(),
      targetRoles: effectiveRoles,
      targetStages: effectiveStages,
      type: 'manual',
      relatedId: ref.id,
    );

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
      final typeKey = type.trim().toLowerCase();
      final isMemberVisitOrFollowUp =
          sender.role == UserRole.member &&
          (typeKey == 'visit' ||
              typeKey == 'visits' ||
              typeKey == 'follow_up' ||
              typeKey == 'followup');

      if (sender.role == UserRole.member && !isMemberVisitOrFollowUp) {
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
      } else if (isMemberVisitOrFollowUp) {
        final senderStageNorm = normalizeStage(sender.stage);
        final mmDocs = await _users
            .where('role', isEqualTo: UserRole.memberManager.value)
            .where('stage_norm', isEqualTo: senderStageNorm)
            .get();

        for (final doc in mmDocs.docs) {
          final uid = (doc.data()['id'] ?? doc.id).toString();
          if (uid.isNotEmpty) recipientIds.add(uid);
        }

        // Backward compatibility if some docs are missing `stage_norm`.
        if (recipientIds.isEmpty) {
          final fallbackDocs = await _users
              .where('role', isEqualTo: UserRole.memberManager.value)
              .where('stage', isEqualTo: sender.stage)
              .get();
          for (final doc in fallbackDocs.docs) {
            final uid = (doc.data()['id'] ?? doc.id).toString();
            if (uid.isNotEmpty) recipientIds.add(uid);
          }
        }
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
        senderId: sender.id,
        isRead: false,
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

      await _dispatchPushNotification(
        sender: sender,
        title: title,
        body: body,
        recipientIds: recipientIds,
        targetRoles: isMemberVisitOrFollowUp
            ? <String>[UserRole.memberManager.value]
            : (targetRoles ?? <String>[]),
        targetStages: isMemberVisitOrFollowUp
            ? <String>[normalizeStage(sender.stage)]
            : (targetStages ?? <String>[]),
        type: type,
        relatedId: relatedId ?? '',
        targetUserId: targetUserId,
      );

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

  Future<void> _dispatchPushNotification({
    required UserModel sender,
    required String title,
    required String body,
    required Set<String> recipientIds,
    required List<String> targetRoles,
    required List<String> targetStages,
    required String type,
    required String relatedId,
    String? targetUserId,
  }) async {
    try {
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

      debugPrint(
        '[NotificationService] push dispatch start type=$type relatedId=$relatedId sender=${sender.id} recipients=${recipientIds.length} roles=$normalizedRoles stages=$normalizedStages targetUserId=${targetUserId ?? ''}',
      );

      if (targetUserId != null && targetUserId.isNotEmpty) {
        final token = await _getUserToken(targetUserId);
        if (token != null && token.isNotEmpty) {
          debugPrint(
            '[NotificationService] push direct token user=$targetUserId type=$type relatedId=$relatedId',
          );
          final ok = await _githubTriggerService.sendNotification(
            title: title,
            body: body,
            token: token,
          );
          debugPrint('[NotificationService] push direct token result=$ok');
          return;
        }
      }

      final hasStageOnlyTargets =
          normalizedStages.isNotEmpty && normalizedRoles.isEmpty;
      final hasRoleAndStageTargets =
          normalizedStages.isNotEmpty && normalizedRoles.isNotEmpty;

      if (hasStageOnlyTargets) {
        for (final stage in normalizedStages) {
          final stageTopic = _toStageTopic(stage);
          debugPrint(
            '[NotificationService] push stage topic=$stageTopic type=$type relatedId=$relatedId',
          );
          final ok = await _githubTriggerService.sendNotification(
            title: title,
            body: body,
            topic: stageTopic,
          );
          debugPrint('[NotificationService] push stage topic result=$ok');
        }
        return;
      }

      if (hasRoleAndStageTargets) {
        // Intersection targeting (role + stage) is safest via direct tokens.
        for (final userId in recipientIds) {
          final token = await _getUserToken(userId);
          if (token == null || token.isEmpty) continue;
          final ok = await _githubTriggerService.sendNotification(
            title: title,
            body: body,
            token: token,
          );
          debugPrint(
            '[NotificationService] push role+stage direct token user=$userId result=$ok',
          );
        }
        return;
      }

      final topics = <String>{};
      if (normalizedRoles.isEmpty) {
        topics.add('all');
      } else {
        topics.addAll(normalizedRoles.map(_mapRoleToTopic));
      }

      for (final topic in topics) {
        debugPrint(
          '[NotificationService] push topic=$topic type=$type relatedId=$relatedId sender=${sender.id}',
        );
        final ok = await _githubTriggerService.sendNotification(
          title: title,
          body: body,
          topic: topic,
        );
        debugPrint('[NotificationService] push topic result=$ok');
      }
    } catch (e) {
      debugPrint('[NotificationService] push dispatch error: $e');
    }
  }

  String _mapRoleToTopic(String role) {
    final normalized = role.trim().toLowerCase();
    switch (normalized) {
      case 'manager':
      case 'managers':
        return 'managers';
      case 'member_manager':
      case 'member_managers':
        return 'member_managers';
      case 'member':
      case 'members':
        return 'members';
      default:
        return normalized;
    }
  }

  String _toStageTopic(String stageNorm) {
    final cleaned = stageNorm.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '_',
    );
    if (cleaned.startsWith('stage_')) return cleaned;
    return 'stage_$cleaned';
  }

  Future<String?> _getUserToken(String userId) async {
    final doc = await _users.doc(userId).get();
    final data = doc.data();
    if (data == null) return null;
    final token = (data['fcmToken'] ?? '').toString().trim();
    return token.isEmpty ? null : token;
  }
}
