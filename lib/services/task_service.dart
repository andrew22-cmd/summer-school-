import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/task_model.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/firestore_user_service.dart';
import 'package:summerschool/services/notification_service.dart';

class TaskService {
  TaskService({
    FirebaseFirestore? firestore,
    FirestoreUserService? firestoreUserService,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firestoreUserService = firestoreUserService ?? FirestoreUserService(),
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirestoreUserService _firestoreUserService;
  final NotificationService _notificationService;

  static const String collection = 'tasks';

  static String normalizeStage(String stage) =>
      stage.replaceAll(' ', '').toLowerCase();

  Stream<List<TaskModel>> watchMyTasks(String currentUserId) {
    final uid = currentUserId.trim();
    if (uid.isEmpty) return Stream.value(const []);

    debugPrint('[TaskService] watchMyTasks uid=$uid');

    return _firestore
        .collection(collection)
        .where('assignedToUserId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
              .toList();
          debugPrint(
            '[TaskService] realtime snapshot received uid=$uid count=${tasks.length}',
          );
          return tasks;
        });
  }

  /// Watch tasks created by current user (for managers/member_managers)
  Stream<List<TaskModel>> watchMyCreatedTasks(String currentUserId) {
    final uid = currentUserId.trim();
    if (uid.isEmpty) return Stream.value(const []);

    debugPrint('[TaskService] watchMyCreatedTasks uid=$uid');

    return _firestore
        .collection(collection)
        .where('assignedByUserId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) {
                try {
                  return TaskModel.fromMap(doc.data(), doc.id);
                } catch (e) {
                  debugPrint('[TaskService] error parsing task doc: $e');
                  return null;
                }
              })
              .whereType<TaskModel>()
              .toList();

          // Sort by created date locally
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          debugPrint(
            '[TaskService] created tasks snapshot received uid=$uid count=${tasks.length}',
          );
          return tasks;
        })
        .handleError((error) {
          debugPrint('[TaskService] watchMyCreatedTasks error: $error');
          return <TaskModel>[];
        });
  }

  Stream<List<UserModel>> watchAllowedAssignees(UserModel currentUser) {
    return _firestoreUserService.watchAllUsers().map((allUsers) {
      final normalizedStage = normalizeStage(currentUser.stage);

      final allowed =
          allUsers.where((user) {
            if (user.id == currentUser.id) return false;

            if (currentUser.role == UserRole.manager) {
              return user.role == UserRole.member ||
                  user.role == UserRole.memberManager;
            }

            if (currentUser.role == UserRole.memberManager) {
              return user.role == UserRole.member &&
                  normalizeStage(user.stage) == normalizedStage;
            }

            return false;
          }).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

      debugPrint(
        '[TaskService] allowed assignees for ${currentUser.role.value} uid=${currentUser.id} stage_norm=$normalizedStage count=${allowed.length}',
      );

      return allowed;
    });
  }

  Future<void> createTask({
    required UserModel assignedBy,
    required UserModel assignedTo,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final ref = _firestore.collection(collection).doc();

    debugPrint(
      '[TaskService] creating task by=${assignedBy.id}/${assignedBy.name} to=${assignedTo.id}/${assignedTo.name} title="$title"',
    );

    await ref.set({
      'id': ref.id,
      'title': title.trim(),
      'description': description.trim(),
      'assignedToUserId': assignedTo.id,
      'assignedToName': assignedTo.name,
      'assignedToRole': assignedTo.role.value,
      'assignedByUserId': assignedBy.id,
      'assignedByName': assignedBy.name,
      'assignedByRole': assignedBy.role.value,
      'stage': assignedTo.stage,
      'stage_norm': normalizeStage(assignedTo.stage),
      'dueDate': Timestamp.fromDate(dueDate),
      'isCompleted': false,
      'completedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'lastEditedBy': null,
      'lastEditedAt': null,
    });

    debugPrint('[TaskService] task created successfully id=${ref.id}');

    // Create automatic notification for assigned user
    try {
      await _notificationService.createAutomaticNotification(
        sender: assignedBy,
        type: 'task',
        title: 'New Task',
        body: 'A new task was assigned to you: ${title.trim()}',
        targetUserId: assignedTo.id,
        relatedId: ref.id,
      );
    } catch (e) {
      debugPrint('[TaskService] notification error: $e');
    }
  }

  Future<void> completeTask(String taskId) async {
    final id = taskId.trim();
    if (id.isEmpty) return;

    debugPrint('[TaskService] complete task id=$id');

    await _firestore.collection(collection).doc(id).update({
      'isCompleted': true,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'lastEditedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[TaskService] task completed id=$id');
  }

  /// Update task and create history entry
  Future<void> updateTask({
    required String taskId,
    required UserModel updatedBy,
    String? title,
    String? description,
    DateTime? dueDate,
  }) async {
    final id = taskId.trim();
    if (id.isEmpty) return;

    debugPrint(
      '[TaskService] updating task id=$id by=${updatedBy.id}/${updatedBy.name}',
    );

    final docRef = _firestore.collection(collection).doc(id);
    final currentDoc = await docRef.get();

    if (!currentDoc.exists) {
      debugPrint('[TaskService] task not found id=$id');
      return;
    }

    final currentData = currentDoc.data() as Map<String, dynamic>;
    final updateData = <String, dynamic>{};
    final historyEntries = <TaskHistoryEntry>[];

    // Track changes
    if (title != null && title.trim() != currentData['title']) {
      updateData['title'] = title.trim();
      historyEntries.add(
        TaskHistoryEntry(
          changedBy: updatedBy.id,
          changedByName: updatedBy.name,
          fieldName: 'Title',
          oldValue: (currentData['title'] ?? '').toString(),
          newValue: title.trim(),
          changedAt: DateTime.now(),
        ),
      );
    }

    if (description != null &&
        description.trim() != currentData['description']) {
      updateData['description'] = description.trim();
      historyEntries.add(
        TaskHistoryEntry(
          changedBy: updatedBy.id,
          changedByName: updatedBy.name,
          fieldName: 'Description',
          oldValue: (currentData['description'] ?? '').toString(),
          newValue: description.trim(),
          changedAt: DateTime.now(),
        ),
      );
    }

    if (dueDate != null) {
      final oldDueDate = currentData['dueDate'];
      final oldDueDateStr = oldDueDate is Timestamp
          ? oldDueDate.toDate().toString()
          : (oldDueDate ?? '').toString();
      final newDueDateStr = dueDate.toString();

      if (oldDueDateStr != newDueDateStr) {
        updateData['dueDate'] = Timestamp.fromDate(dueDate);
        historyEntries.add(
          TaskHistoryEntry(
            changedBy: updatedBy.id,
            changedByName: updatedBy.name,
            fieldName: 'Due Date',
            oldValue: oldDueDateStr,
            newValue: newDueDateStr,
            changedAt: DateTime.now(),
          ),
        );
      }
    }

    if (updateData.isEmpty) {
      debugPrint('[TaskService] no changes to update');
      return;
    }

    // Add history entries to existing history
    final existingHistory =
        (currentData['history'] as List<dynamic>?)?.toList() ?? [];
    final newHistoryEntries = historyEntries
        .map((entry) => entry.toMap())
        .toList();
    existingHistory.addAll(newHistoryEntries);

    updateData['history'] = existingHistory;
    updateData['lastEditedBy'] = updatedBy.name;
    updateData['lastEditedAt'] = FieldValue.serverTimestamp();

    await docRef.update(updateData);

    debugPrint(
      '[TaskService] task updated id=$id with ${historyEntries.length} history entries',
    );
  }

  /// Get task history
  Future<List<TaskHistoryEntry>> getTaskHistory(String taskId) async {
    final id = taskId.trim();
    if (id.isEmpty) return [];

    debugPrint('[TaskService] fetching history for task id=$id');

    final docRef = _firestore.collection(collection).doc(id);
    final doc = await docRef.get();

    if (!doc.exists) {
      debugPrint('[TaskService] task not found id=$id');
      return [];
    }

    final data = doc.data() as Map<String, dynamic>;
    final historyList =
        (data['history'] as List<dynamic>?)
            ?.map((e) => TaskHistoryEntry.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Sort by most recent first
    historyList.sort((a, b) => b.changedAt.compareTo(a.changedAt));

    debugPrint(
      '[TaskService] fetched ${historyList.length} history entries for task id=$id',
    );

    return historyList;
  }

  /// Watch all tasks (for managers and member managers)
  Stream<List<TaskModel>> watchAllTasks({
    required UserModel currentUser,
    String? searchQuery,
    String? statusFilter,
    String? stageFilter,
    String? roleFilter,
  }) {
    Query query = _firestore.collection(collection);

    // Filter by stage for member_managers
    if (currentUser.role == UserRole.memberManager) {
      final normalizedStage = normalizeStage(currentUser.stage);
      query = query.where('stage_norm', isEqualTo: normalizedStage);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      var tasks = snapshot.docs
          .map(
            (doc) =>
                TaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Apply filters
      if (statusFilter != null && statusFilter.isNotEmpty) {
        tasks = tasks.where((t) => t.status == statusFilter).toList();
      }

      if (stageFilter != null && stageFilter.isNotEmpty) {
        final normalized = normalizeStage(stageFilter);
        tasks = tasks.where((t) => t.stageNorm == normalized).toList();
      }

      if (roleFilter != null && roleFilter.isNotEmpty) {
        tasks = tasks.where((t) => t.assignedToRole == roleFilter).toList();
      }

      // Apply search
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        tasks = tasks
            .where(
              (t) =>
                  t.title.toLowerCase().contains(query) ||
                  t.assignedToName.toLowerCase().contains(query),
            )
            .toList();
      }

      debugPrint(
        '[TaskService] watchAllTasks snapshot: user=${currentUser.role.value}, total=${snapshot.docs.length}, filtered=${tasks.length}',
      );

      return tasks;
    });
  }

  /// Update task status
  Future<void> updateTaskStatus({
    required String taskId,
    required String newStatus,
    required UserModel updatedBy,
  }) async {
    final id = taskId.trim();
    if (id.isEmpty) return;

    debugPrint(
      '[TaskService] updating status id=$id to=$newStatus by=${updatedBy.id}',
    );

    final docRef = _firestore.collection(collection).doc(id);
    final currentDoc = await docRef.get();

    if (!currentDoc.exists) {
      debugPrint('[TaskService] task not found id=$id');
      return;
    }

    final currentData = currentDoc.data() as Map<String, dynamic>;
    final oldStatus = (currentData['status'] ?? 'pending').toString();

    if (oldStatus == newStatus) {
      debugPrint('[TaskService] status unchanged, skipping update');
      return;
    }

    // Create history entry
    final historyEntry = TaskHistoryEntry(
      changedBy: updatedBy.id,
      changedByName: updatedBy.name,
      fieldName: 'Status',
      oldValue: oldStatus,
      newValue: newStatus,
      changedAt: DateTime.now(),
    );

    // Add to existing history
    final existingHistory =
        (currentData['history'] as List<dynamic>?)?.toList() ?? [];
    existingHistory.add(historyEntry.toMap());

    await docRef.update({
      'status': newStatus,
      'lastEditedBy': updatedBy.name,
      'lastEditedAt': FieldValue.serverTimestamp(),
      'history': existingHistory,
    });

    debugPrint('[TaskService] status updated id=$id to=$newStatus');
  }

  /// Delete task (with permission checks)
  Future<void> deleteTask({
    required String taskId,
    required UserModel currentUser,
  }) async {
    final id = taskId.trim();
    if (id.isEmpty) return;

    debugPrint(
      '[TaskService] deleting task id=$id by=${currentUser.id}/${currentUser.role.value}',
    );

    final docRef = _firestore.collection(collection).doc(id);
    final doc = await docRef.get();

    if (!doc.exists) {
      debugPrint('[TaskService] task not found id=$id');
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final createdByUserId = (data['assignedByUserId'] ?? '').toString();

    // Permission check: manager can delete any, member_manager can only delete their own
    final canDelete =
        currentUser.role == UserRole.manager ||
        (currentUser.role == UserRole.memberManager &&
            createdByUserId == currentUser.id);

    if (!canDelete) {
      debugPrint(
        '[TaskService] permission denied: user=${currentUser.role.value} not allowed to delete',
      );
      return;
    }

    await docRef.delete();

    debugPrint('[TaskService] task deleted id=$id');
  }
}
