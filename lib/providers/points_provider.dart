import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/points_history_model.dart';
import 'package:summerschool/services/points_service.dart';

class PointsProvider extends ChangeNotifier {
  PointsProvider(this._service);

  final PointsService _service;

  List<ClassMemberModel> _students = [];
  List<PointsHistoryModel> _history = [];
  final Map<String, PointsHistoryModel> _latestHistoryByStudentId = {};
  final Map<String, int> _currentTotalByStudentId = {};
  bool _isLoadingStudents = false;
  bool _isLoadingHistory = false;
  String? _error;
  String _search = '';

  StreamSubscription<List<ClassMemberModel>>? _studentsSub;
  StreamSubscription<List<PointsHistoryModel>>? _totalsSub;
  StreamSubscription<List<PointsHistoryModel>>? _historySub;

  List<ClassMemberModel> get allStudents => _students;

  List<ClassMemberModel> get students {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return _students.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  List<PointsHistoryModel> get history => _history;
  bool get isLoadingStudents => _isLoadingStudents;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  int? currentTotalForStudent(String studentId) {
    return _currentTotalByStudentId[studentId];
  }

  PointsHistoryModel? latestHistoryForStudent(String studentId) {
    return _latestHistoryByStudentId[studentId];
  }

  void setSearch(String value) {
    _search = value;
    debugPrint(
      '[PROVIDER NOTIFY] PointsProvider.setSearch("$value") - triggering rebuild',
    );
    notifyListeners();
  }

  Future<void> startListeningStudents(String stage) async {
    debugPrint(
      '[STREAM UPDATE] PointsProvider.startListeningStudents() called for stage="$stage"',
    );
    _students = [];
    _setLoadingStudents(true);
    _error = null;
    await _studentsSub?.cancel();
    debugPrint('[STREAM UPDATE] Old subscription canceled');
    _studentsSub = _service
        .watchStudentsForStage(stage)
        .listen(
          (list) {
            debugPrint(
              '[STREAM] PointsProvider snapshot received count=${list.length}',
            );
            for (final student in list) {
              debugPrint(
                '[STREAM] member name="${student.name}" totalPoints=${student.totalPoints}',
              );
            }
            _students = list;
            _setLoadingStudents(false);
            notifyListeners();
            debugPrint(
              '[STREAM] ✓ notifyListeners() fired - UI should rebuild',
            );
          },
          onError: (e) {
            debugPrint(
              '[PointsProvider.startListeningStudents] ❌ Stream error: $e',
            );
            _error = e.toString();
            _setLoadingStudents(false);
            notifyListeners();
          },
        );
    debugPrint(
      '[STREAM UPDATE] New listener attached and waiting for snapshots',
    );
  }

  Future<void> startListeningHistory(String stage, {String? studentId}) async {
    debugPrint(
      '[STREAM UPDATE] PointsProvider.startListeningHistory() called for stage="$stage", studentId="$studentId"',
    );
    _history = [];
    _setLoadingHistory(true);
    _error = null;
    await _historySub?.cancel();
    debugPrint('[STREAM UPDATE] Old history subscription canceled');
    _historySub = _service
        .watchHistoryForStage(stage, studentId: studentId)
        .listen(
          (list) {
            debugPrint(
              '[STREAM] PointsProvider history snapshot received count=${list.length}',
            );
            for (final entry in list) {
              debugPrint(
                '[STREAM] history operationType="${entry.operationType}" points=${entry.points} totalPointsAfterOperation=${entry.totalPointsAfterOperation}',
              );
            }
            _history = list;
            _rebuildLatestTotals(list);
            _setLoadingHistory(false);
            debugPrint(
              '[PROVIDER NOTIFY] PointsProvider notifying UI after history snapshot',
            );
            notifyListeners();
            debugPrint(
              '[STREAM] ✓ notifyListeners() fired - history UI should rebuild',
            );
          },
          onError: (e) {
            debugPrint(
              '[PointsProvider.startListeningHistory] ❌ Stream error: $e',
            );
            _error = e.toString();
            _setLoadingHistory(false);
            notifyListeners();
          },
        );
    debugPrint(
      '[STREAM UPDATE] New history listener attached and waiting for snapshots',
    );
  }

  Future<void> startListeningTotals(String stage) async {
    debugPrint(
      '[STREAM UPDATE] PointsProvider.startListeningTotals() called for stage="$stage"',
    );
    _history = [];
    _setLoadingHistory(true);
    _error = null;
    await _totalsSub?.cancel();
    debugPrint('[STREAM UPDATE] Old totals subscription canceled');
    _totalsSub = _service
        .watchHistoryForStage(stage)
        .listen(
          (list) {
            debugPrint(
              '[STREAM] PointsProvider totals snapshot received count=${list.length}',
            );
            for (final entry in list) {
              debugPrint(
                '[STREAM] totals entry studentId="${entry.studentId}" operationType="${entry.operationType}" totalPointsAfterOperation=${entry.totalPointsAfterOperation}',
              );
            }
            _history = list;
            _rebuildLatestTotals(list);
            _setLoadingHistory(false);
            debugPrint(
              '[PROVIDER NOTIFY] PointsProvider notifying UI after totals snapshot',
            );
            notifyListeners();
            debugPrint(
              '[STREAM] ✓ notifyListeners() fired - totals UI should rebuild',
            );
          },
          onError: (e) {
            debugPrint(
              '[PointsProvider.startListeningTotals] ❌ Stream error: $e',
            );
            _error = e.toString();
            _setLoadingHistory(false);
            notifyListeners();
          },
        );
    debugPrint(
      '[STREAM UPDATE] New totals listener attached and waiting for snapshots',
    );
  }

  Future<void> addPoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdBy,
  }) async {
    debugPrint('[PointsProvider.addPoints] Calling service.addPoints()...');
    try {
      await _service.addPoints(
        student: student,
        points: points,
        reason: reason,
        createdBy: createdBy,
      );
      debugPrint('[PointsProvider.addPoints] ✓ Service completed successfully');
    } catch (e) {
      debugPrint('[PointsProvider.addPoints] ❌ Service failed: $e');
      rethrow;
    }
  }

  Future<void> removePoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdBy,
  }) async {
    debugPrint(
      '[PointsProvider.removePoints] Calling service.removePoints()...',
    );
    try {
      await _service.removePoints(
        student: student,
        points: points,
        reason: reason,
        createdBy: createdBy,
      );
      debugPrint(
        '[PointsProvider.removePoints] ✓ Service completed successfully',
      );
    } catch (e) {
      debugPrint('[PointsProvider.removePoints] ❌ Service failed: $e');
      rethrow;
    }
  }

  Future<int> cleanupOldHistory() {
    return _service.cleanupHistoryOlderThan(const Duration(days: 7));
  }

  void _setLoadingStudents(bool value) {
    if (_isLoadingStudents == value) return; // Don't notify if no change
    _isLoadingStudents = value;
    debugPrint('[PROVIDER NOTIFY] PointsProvider _isLoadingStudents=$value');
  }

  void _setLoadingHistory(bool value) {
    if (_isLoadingHistory == value) return; // Don't notify if no change
    _isLoadingHistory = value;
    debugPrint('[PROVIDER NOTIFY] PointsProvider _isLoadingHistory=$value');
  }

  void _rebuildLatestTotals(List<PointsHistoryModel> list) {
    _latestHistoryByStudentId.clear();
    _currentTotalByStudentId.clear();

    for (final entry in list) {
      _latestHistoryByStudentId.putIfAbsent(entry.studentId, () => entry);
      _currentTotalByStudentId.putIfAbsent(
        entry.studentId,
        () => entry.totalPointsAfterOperation,
      );
    }

    debugPrint(
      '[TOTAL POINTS UPDATED] rebuilt live totals for ${_currentTotalByStudentId.length} students from points_history',
    );
    for (final e in _currentTotalByStudentId.entries) {
      debugPrint(
        '[TOTAL POINTS UPDATED] studentId=${e.key} currentTotal=${e.value}',
      );
    }
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _totalsSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }
}
