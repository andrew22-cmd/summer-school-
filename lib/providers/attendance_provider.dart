import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:summerschool/models/attendance_model.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({AttendanceService? service})
    : _service = service ?? AttendanceService();

  final AttendanceService _service;

  List<ClassMemberModel> _students = [];
  Map<String, Map<String, AttendanceModel>> _attendanceByDate = {};
  final Map<String, Map<String, bool>> _draftByDate = {};
  bool _isLoadingStudents = false;
  bool _isLoadingAttendance = false;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _needsAutoEditModeSync = true;
  String? _error;
  String _search = '';
  String? _currentStage;
  DateTime _selectedDate = DateTime.now();

  StreamSubscription<List<ClassMemberModel>>? _studentsSub;
  StreamSubscription<List<AttendanceModel>>? _attendanceSub;

  List<ClassMemberModel> get allStudents => _students;

  List<ClassMemberModel> get students {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return _students.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  bool get isLoadingStudents => _isLoadingStudents;
  bool get isLoadingAttendance => _isLoadingAttendance;
  bool get isSaving => _isSaving;
  bool get isEditMode => _isEditMode;
  String? get error => _error;
  String get selectedDateKey => AttendanceService.dateKey(_selectedDate);
  String get selectedEnglishDayName =>
      AttendanceService.dayNameEnglish(_selectedDate);
  String get selectedArabicDayName =>
      AttendanceService.dayNameArabic(_selectedDate);
  String get formattedSelectedDate => selectedDateKey;
  DateTime get selectedDate => _selectedDate;

  bool get hasPendingChanges {
    final key = selectedDateKey;
    final draft = _draftByDate[key];
    if (draft == null || draft.isEmpty) return false;
    final saved = _attendanceByDate[key] ?? {};
    for (final entry in draft.entries) {
      final savedValue = saved[entry.key]?.isPresent ?? false;
      if (savedValue != entry.value) return true;
    }
    return false;
  }

  bool checkIfAttendanceExists(DateTime date) {
    final key = AttendanceService.dateKey(date);
    return _attendanceByDate[key]?.isNotEmpty ?? false;
  }

  void setSearch(String value) {
    _search = value;
    debugPrint('[PROVIDER NOTIFY] AttendanceProvider.setSearch("$value")');
    notifyListeners();
  }

  Future<void> startListening(String stage, {DateTime? initialDate}) async {
    final normalized = AttendanceService.normalizeStage(stage);
    if (_currentStage == normalized &&
        _studentsSub != null &&
        _attendanceSub != null) {
      if (initialDate != null) {
        _selectedDate = DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        );
        notifyListeners();
      }
      debugPrint(
        '[STREAM] AttendanceProvider already listening to stage="$stage"',
      );
      return;
    }

    _currentStage = normalized;
    if (initialDate != null) {
      _selectedDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );
    }
    _needsAutoEditModeSync = true;

    _error = null;
    _setLoadingStudents(true);
    _setLoadingAttendance(true);

    await _studentsSub?.cancel();
    await _attendanceSub?.cancel();

    debugPrint(
      '[STREAM START] AttendanceProvider.startListening() stage="$stage" normalized="$normalized"',
    );

    _studentsSub = _service
        .watchStudentsForStage(stage)
        .listen(
          (list) {
            debugPrint(
              '[STREAM] AttendanceProvider students snapshot count=${list.length}',
            );
            _students = list;
            _setLoadingStudents(false);
            _syncEditModeWithSelectedDate(reason: 'students snapshot');
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[STREAM] AttendanceProvider students error=$e');
            _error = e.toString();
            _setLoadingStudents(false);
            notifyListeners();
          },
        );

    _attendanceSub = _service
        .watchAttendanceForStage(stage)
        .listen(
          (list) {
            debugPrint(
              '[STREAM] AttendanceProvider attendance snapshot count=${list.length}',
            );
            _attendanceByDate = _groupByDateAndStudent(list);
            _setLoadingAttendance(false);
            _syncEditModeWithSelectedDate(reason: 'attendance snapshot');
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[STREAM] AttendanceProvider attendance error=$e');
            _error = e.toString();
            _setLoadingAttendance(false);
            notifyListeners();
          },
        );
  }

  void setDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (_selectedDate.year == normalized.year &&
        _selectedDate.month == normalized.month &&
        _selectedDate.day == normalized.day) {
      return;
    }
    _selectedDate = normalized;
    _needsAutoEditModeSync = true;
    debugPrint(
      '[PROVIDER NOTIFY] AttendanceProvider.setDate() => $selectedDateKey ${selectedEnglishDayName} (${selectedArabicDayName})',
    );
    _syncEditModeWithSelectedDate(reason: 'setDate');
    notifyListeners();
  }

  void enableEditMode() {
    if (_isEditMode) return;
    _isEditMode = true;
    _needsAutoEditModeSync = false;
    debugPrint('[PROVIDER NOTIFY] AttendanceProvider.enableEditMode()');
    notifyListeners();
  }

  void disableEditMode() {
    if (!_isEditMode) return;
    _isEditMode = false;
    _needsAutoEditModeSync = false;
    debugPrint('[PROVIDER NOTIFY] AttendanceProvider.disableEditMode()');
    notifyListeners();
  }

  void syncEditModeFromCachedAttendance() {
    if (_isLoadingAttendance) {
      debugPrint(
        '[ATTENDANCE MODE] sync skipped because attendance is still loading for $selectedDateKey',
      );
      return;
    }
    _needsAutoEditModeSync = true;
    _syncEditModeWithSelectedDate(reason: 'cached data refresh');
    notifyListeners();
  }

  void previousDay() =>
      setDate(_selectedDate.subtract(const Duration(days: 1)));
  void nextDay() => setDate(_selectedDate.add(const Duration(days: 1)));

  bool isPresent(String studentId) {
    final key = selectedDateKey;
    final draft = _draftByDate[key];
    if (draft != null && draft.containsKey(studentId)) {
      return draft[studentId] ?? false;
    }
    return _attendanceByDate[key]?[studentId]?.isPresent ?? false;
  }

  void toggleAttendance(String studentId) {
    if (!_isEditMode) {
      debugPrint(
        '[ATTENDANCE] toggleAttendance ignored because edit mode is OFF for studentId=$studentId',
      );
      return;
    }
    final key = selectedDateKey;
    final current = isPresent(studentId);
    final draft = _draftByDate.putIfAbsent(key, () => <String, bool>{});
    draft[studentId] = !current;
    debugPrint(
      '[UI REBUILD] AttendanceProvider.toggleAttendance(studentId=$studentId) => ${draft[studentId]} for date=$key',
    );
    notifyListeners();
  }

  Future<void> saveAttendance({required String updatedBy}) async {
    if (_currentStage == null || _currentStage!.trim().isEmpty) {
      throw Exception('Stage is not ready yet.');
    }
    if (_students.isEmpty) {
      throw Exception('No students loaded.');
    }

    _isSaving = true;
    notifyListeners();

    try {
      final attendanceByStudentId = <String, bool>{};
      for (final student in _students) {
        attendanceByStudentId[student.id] = isPresent(student.id);
      }

      await _service.saveAttendance(
        stage: _students.first.stage,
        date: _selectedDate,
        students: _students,
        attendanceByStudentId: attendanceByStudentId,
        updatedBy: updatedBy,
      );

      _draftByDate.remove(selectedDateKey);
      debugPrint(
        '[ATTENDANCE SAVE] Provider cleared draft for $selectedDateKey',
      );
      _isEditMode = false;
      _needsAutoEditModeSync = false;
      debugPrint(
        '[PROVIDER NOTIFY] AttendanceProvider auto-switched to VIEW mode',
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _setLoadingStudents(bool value) {
    if (_isLoadingStudents == value) return;
    _isLoadingStudents = value;
    debugPrint(
      '[PROVIDER NOTIFY] AttendanceProvider _isLoadingStudents=$value',
    );
  }

  void _setLoadingAttendance(bool value) {
    if (_isLoadingAttendance == value) return;
    _isLoadingAttendance = value;
    debugPrint(
      '[PROVIDER NOTIFY] AttendanceProvider _isLoadingAttendance=$value',
    );
  }

  void _syncEditModeWithSelectedDate({required String reason}) {
    if (!_needsAutoEditModeSync) return;
    if (_isLoadingAttendance) {
      debugPrint(
        '[ATTENDANCE MODE] sync deferred from $reason because attendance is still loading for $selectedDateKey',
      );
      return;
    }

    final exists = checkIfAttendanceExists(_selectedDate);
    final shouldEdit = !exists;

    debugPrint(
      '[ATTENDANCE MODE] sync from $reason for $selectedDateKey exists=$exists => isEditMode=$shouldEdit',
    );

    if (_isEditMode != shouldEdit) {
      _isEditMode = shouldEdit;
      debugPrint(
        '[PROVIDER NOTIFY] AttendanceProvider auto-set edit mode = $_isEditMode',
      );
    }

    _needsAutoEditModeSync = false;
  }

  Map<String, Map<String, AttendanceModel>> _groupByDateAndStudent(
    List<AttendanceModel> list,
  ) {
    final grouped = <String, Map<String, AttendanceModel>>{};
    for (final item in list) {
      grouped.putIfAbsent(item.date, () => <String, AttendanceModel>{});
      grouped[item.date]![item.studentId] = item;
    }
    return grouped;
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _attendanceSub?.cancel();
    super.dispose();
  }
}
