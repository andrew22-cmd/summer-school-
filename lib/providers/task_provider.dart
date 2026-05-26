import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:summerschool/models/task_model.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider({required TaskService service}) : _service = service;

  final TaskService _service;

  List<TaskModel> _myTasks = [];
  List<TaskModel> _myCreatedTasks = [];
  List<TaskModel> _allTasks = [];
  List<UserModel> _allowedAssignees = [];
  bool _isLoadingMyTasks = false;
  bool _isLoadingMyCreatedTasks = false;
  bool _isLoadingAllTasks = false;
  bool _isLoadingAssignees = false;
  bool _isCreatingTask = false;
  String? _myTasksError;
  String? _myCreatedTasksError;
  String? _allTasksError;
  String? _assigneesError;

  StreamSubscription<List<TaskModel>>? _myTasksSub;
  StreamSubscription<List<TaskModel>>? _myCreatedTasksSub;
  StreamSubscription<List<TaskModel>>? _allTasksSub;
  StreamSubscription<List<UserModel>>? _assigneesSub;

  List<TaskModel> get myTasks => _myTasks;
  List<TaskModel> get myCreatedTasks => _myCreatedTasks;
  List<TaskModel> get allTasks => _allTasks;
  List<UserModel> get allowedAssignees => _allowedAssignees;
  bool get isLoadingMyTasks => _isLoadingMyTasks;
  bool get isLoadingMyCreatedTasks => _isLoadingMyCreatedTasks;
  bool get isLoadingAllTasks => _isLoadingAllTasks;
  bool get isLoadingAssignees => _isLoadingAssignees;
  bool get isCreatingTask => _isCreatingTask;
  String? get myTasksError => _myTasksError;
  String? get myCreatedTasksError => _myCreatedTasksError;
  String? get allTasksError => _allTasksError;
  String? get assigneesError => _assigneesError;

  void startMyTasks(String userId) {
    _myTasksSub?.cancel();
    _setLoadingMyTasks(true);
    _myTasksError = null;

    _myTasksSub = _service
        .watchMyTasks(userId)
        .listen(
          (tasks) {
            _myTasks = tasks;
            _setLoadingMyTasks(false);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('[TaskProvider] myTasks stream error: $error');
            _myTasksError = error.toString();
            _setLoadingMyTasks(false);
            notifyListeners();
          },
        );
  }

  void startMyCreatedTasks(String userId) {
    _myCreatedTasksSub?.cancel();
    _setLoadingMyCreatedTasks(true);
    _myCreatedTasksError = null;

    _myCreatedTasksSub = _service
        .watchMyCreatedTasks(userId)
        .listen(
          (tasks) {
            _myCreatedTasks = tasks;
            _setLoadingMyCreatedTasks(false);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('[TaskProvider] myCreatedTasks stream error: $error');
            _myCreatedTasksError = error.toString();
            _setLoadingMyCreatedTasks(false);
            notifyListeners();
          },
        );
  }

  void startAllowedAssignees(UserModel currentUser) {
    _assigneesSub?.cancel();
    _setLoadingAssignees(true);
    _assigneesError = null;

    _assigneesSub = _service
        .watchAllowedAssignees(currentUser)
        .listen(
          (users) {
            _allowedAssignees = users;
            _setLoadingAssignees(false);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('[TaskProvider] allowedAssignees stream error: $error');
            _assigneesError = error.toString();
            _setLoadingAssignees(false);
            notifyListeners();
          },
        );
  }

  Future<void> createTask({
    required UserModel assignedBy,
    required UserModel assignedTo,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    _isCreatingTask = true;
    notifyListeners();

    try {
      await _service.createTask(
        assignedBy: assignedBy,
        assignedTo: assignedTo,
        title: title,
        description: description,
        dueDate: dueDate,
      );
    } catch (e) {
      debugPrint('[TaskProvider] createTask error: $e');
      rethrow;
    } finally {
      _isCreatingTask = false;
      notifyListeners();
    }
  }

  Future<void> completeTask(String taskId) async {
    try {
      await _service.completeTask(taskId);
    } catch (e) {
      debugPrint('[TaskProvider] completeTask error: $e');
      rethrow;
    }
  }

  Future<void> updateTask({
    required String taskId,
    required UserModel updatedBy,
    String? title,
    String? description,
    DateTime? dueDate,
  }) async {
    try {
      await _service.updateTask(
        taskId: taskId,
        updatedBy: updatedBy,
        title: title,
        description: description,
        dueDate: dueDate,
      );
    } catch (e) {
      debugPrint('[TaskProvider] updateTask error: $e');
      rethrow;
    }
  }

  Future<List<TaskHistoryEntry>> getTaskHistory(String taskId) async {
    try {
      return await _service.getTaskHistory(taskId);
    } catch (e) {
      debugPrint('[TaskProvider] getTaskHistory error: $e');
      rethrow;
    }
  }

  void startAllTasks(
    UserModel currentUser, {
    String? searchQuery,
    String? statusFilter,
    String? stageFilter,
    String? roleFilter,
  }) {
    _allTasksSub?.cancel();
    _setLoadingAllTasks(true);
    _allTasksError = null;

    _allTasksSub = _service
        .watchAllTasks(
          currentUser: currentUser,
          searchQuery: searchQuery,
          statusFilter: statusFilter,
          stageFilter: stageFilter,
          roleFilter: roleFilter,
        )
        .listen(
          (tasks) {
            _allTasks = tasks;
            _setLoadingAllTasks(false);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('[TaskProvider] allTasks stream error: $error');
            _allTasksError = error.toString();
            _setLoadingAllTasks(false);
            notifyListeners();
          },
        );
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String newStatus,
    required UserModel updatedBy,
  }) async {
    try {
      await _service.updateTaskStatus(
        taskId: taskId,
        newStatus: newStatus,
        updatedBy: updatedBy,
      );
    } catch (e) {
      debugPrint('[TaskProvider] updateTaskStatus error: $e');
      rethrow;
    }
  }

  Future<void> deleteTask({
    required String taskId,
    required UserModel currentUser,
  }) async {
    try {
      await _service.deleteTask(taskId: taskId, currentUser: currentUser);
    } catch (e) {
      debugPrint('[TaskProvider] deleteTask error: $e');
      rethrow;
    }
  }

  List<UserModel> searchAllowedAssignees(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _allowedAssignees;
    return _allowedAssignees
        .where((u) => u.name.toLowerCase().contains(q))
        .toList();
  }

  void _setLoadingMyTasks(bool value) {
    if (_isLoadingMyTasks == value) return;
    _isLoadingMyTasks = value;
    notifyListeners();
  }

  void _setLoadingMyCreatedTasks(bool value) {
    if (_isLoadingMyCreatedTasks == value) return;
    _isLoadingMyCreatedTasks = value;
    notifyListeners();
  }

  void _setLoadingAllTasks(bool value) {
    if (_isLoadingAllTasks == value) return;
    _isLoadingAllTasks = value;
    notifyListeners();
  }

  void _setLoadingAssignees(bool value) {
    if (_isLoadingAssignees == value) return;
    _isLoadingAssignees = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _myTasksSub?.cancel();
    _myCreatedTasksSub?.cancel();
    _allTasksSub?.cancel();
    _assigneesSub?.cancel();
    super.dispose();
  }
}
