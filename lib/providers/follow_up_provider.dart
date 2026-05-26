import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/models/follow_up_model.dart';
import 'package:summerschool/services/follow_up_service.dart';

class FollowUpProvider extends ChangeNotifier {
  FollowUpProvider({required FollowUpService service}) : _service = service;

  final FollowUpService _service;

  List<ClassMemberModel> _students = [];
  Map<String, List<FollowUpModel>> _monthlyVisitsByStudentId = {};
  bool _isLoading = false;
  String? _error;
  String _currentStage = '';
  DateTime _currentMonthStart = FollowUpService.weekStartOf(DateTime.now());

  StreamSubscription<List<ClassMemberModel>>? _studentsSub;
  StreamSubscription<List<FollowUpModel>>? _followUpsSub;

  List<ClassMemberModel> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentStage => _currentStage;
  DateTime get currentMonthStart => _currentMonthStart;

  /// Returns true when the student reached target visits (2+) for month
  bool contactedForStudent(String studentId) {
    final list = _monthlyVisitsByStudentId[studentId];
    if (list == null || list.isEmpty) return false;
    return list.length >= 2;
  }

  /// Return latest visit record for the student in selected month
  FollowUpModel? followUpForStudent(String studentId) {
    final list = _monthlyVisitsByStudentId[studentId];
    if (list == null || list.isEmpty) return null;
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return list.first;
  }

  /// Returns number of visits recorded for the student in selected month
  int visitsCountForStudent(String studentId) {
    return _monthlyVisitsByStudentId[studentId]?.length ?? 0;
  }

  void startListening(
    String stage, {
    DateTime? monthDate,
    String? requesterRole,
    String? requesterStage,
  }) {
    final normalized = FollowUpService.normalizeStage(stage);
    final selectedMonthStart = FollowUpService.weekStartOf(
      monthDate ?? DateTime.now(),
    );

    if (_currentStage == normalized &&
        _currentMonthStart == selectedMonthStart &&
        _studentsSub != null &&
        _followUpsSub != null) {
      debugPrint(
        '[FollowUpProvider] already listening for stage_norm="$normalized"',
      );
      return;
    }

    _currentStage = normalized;
    _currentMonthStart = selectedMonthStart;
    _error = null;

    _studentsSub?.cancel();
    _followUpsSub?.cancel();
    _studentsSub = null;
    _followUpsSub = null;

    if (normalized.isEmpty) {
      _students = [];
      _monthlyVisitsByStudentId = {};
      _setLoading(false);
      return;
    }

    _setLoading(true);

    debugPrint(
      '[FollowUpProvider] startListening stage="$stage" stage_norm="$normalized" month=${FollowUpService.monthLabel(_currentMonthStart)} requesterRole=${requesterRole ?? 'unknown'} requesterStage=${requesterStage ?? stage}',
    );

    _studentsSub = _service
        .watchStudentsForStage(
          stage,
          requesterRole: requesterRole ?? 'manager',
          requesterStage: requesterStage ?? stage,
        )
        .listen(
          (students) {
            _students = students;
            _setLoading(false);
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            _setLoading(false);
            notifyListeners();
          },
        );

    _followUpsSub = _service
        .watchMonthlyVisitsForStage(
          stage,
          requesterRole: requesterRole ?? 'manager',
          requesterStage: requesterStage ?? stage,
          monthDate: _currentMonthStart,
        )
        .listen(
          (visits) {
            _monthlyVisitsByStudentId = {
              for (final v in visits) v.studentId: [],
            };
            for (final v in visits) {
              _monthlyVisitsByStudentId
                  .putIfAbsent(v.studentId, () => [])
                  .add(v);
            }
            _setLoading(false);
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            _setLoading(false);
            notifyListeners();
          },
        );
  }

  Stream<List<FollowUpModel>> watchMonthlyVisitsForStudent({
    required String studentId,
    required String stage,
    DateTime? monthDate,
    String? requesterRole,
    String? requesterStage,
  }) {
    return _service.watchVisitsForStudentMonth(
      studentId: studentId,
      stage: stage,
      requesterRole: requesterRole ?? 'manager',
      requesterStage: requesterStage ?? stage,
      monthDate: monthDate ?? _currentMonthStart,
    );
  }

  Future<void> saveVisit({
    required String studentId,
    required String studentName,
    required String stage,
    required String servantId,
    required String servantName,
    required String createdByRole,
    required DateTime visitDate,
    required bool responded,
    required String visitType,
    required String summary,
    required String notes,
    required String favoriteThing,
    DateTime? nextFollowUp,
  }) {
    return _service.saveVisit(
      studentId: studentId,
      studentName: studentName,
      stage: stage,
      servantId: servantId,
      servantName: servantName,
      createdByRole: createdByRole,
      visitDate: visitDate,
      responded: responded,
      visitType: visitType,
      summary: summary,
      notes: notes,
      favoriteThing: favoriteThing,
      nextFollowUp: nextFollowUp,
    );
  }

  Future<void> disposeStreams() async {
    await _studentsSub?.cancel();
    await _followUpsSub?.cancel();
    _studentsSub = null;
    _followUpsSub = null;
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _followUpsSub?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}
