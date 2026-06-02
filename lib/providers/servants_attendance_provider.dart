import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/servant_attendance_model.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/servants_attendance_service.dart';

class ServantsAttendanceProvider extends ChangeNotifier {
  ServantsAttendanceProvider({ServantsAttendanceService? service})
    : _service = service ?? ServantsAttendanceService();

  final ServantsAttendanceService _service;

  UserModel? _currentUser;
  List<UserModel> _servants = [];
  List<String> _availableStages = [];
  Map<String, ServantAttendanceModel> _attendanceByServantId = {};
  Map<String, bool> _draft = {};
  DateTime _selectedDate = DateTime.now();
  String _selectedStage = '';
  bool _isLoadingServants = false;
  bool _isLoadingAttendance = false;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _needsAutoEditModeSync = true;
  String _search = '';
  String? _error;

  StreamSubscription<List<UserModel>>? _servantsSub;
  StreamSubscription<List<ServantAttendanceModel>>? _attendanceSub;
  StreamSubscription<List<String>>? _stagesSub;

  List<UserModel> get allServants => _servants;
  List<UserModel> get servants {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _servants;
    return _servants.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  List<String> get availableStages => _availableStages;
  String get selectedStage => _selectedStage;
  DateTime get selectedDate => _selectedDate;
  bool get isLoadingServants => _isLoadingServants;
  bool get isLoadingAttendance => _isLoadingAttendance;
  bool get isSaving => _isSaving;
  bool get isEditMode => _isEditMode;
  String? get error => _error;

  String get selectedDateKey =>
      ServantsAttendanceService.dateKey(_selectedDate);
  String get dayNameArabic =>
      ServantsAttendanceService.dayNameArabic(_selectedDate);

  bool get isManager => _currentUser?.role == UserRole.manager;
  bool get isMemberManager => _currentUser?.role == UserRole.memberManager;
  bool get isMember => _currentUser?.role == UserRole.member;
  bool get canEdit => isMemberManager || isMember || isManager;

  bool get hasPendingChanges {
    if (_draft.isEmpty) return false;
    for (final e in _draft.entries) {
      final savedValue = _attendanceByServantId[e.key]?.attended ?? false;
      if (savedValue != e.value) return true;
    }
    return false;
  }

  bool get attendanceExists => _attendanceByServantId.isNotEmpty;

  Future<void> startListening({
    required UserModel user,
    String? forcedStage,
    DateTime? initialDate,
  }) async {
    _currentUser = user;
    if (initialDate != null) {
      _selectedDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );
    }

    if (isManager) {
      await _stagesSub?.cancel();
      _stagesSub = _service.watchServantStages().listen((stages) {
        _availableStages = stages;
        final preferred = (forcedStage ?? _selectedStage).trim();
        if (preferred.isNotEmpty &&
            stages.any(
              (s) =>
                  ServantsAttendanceService.normalizeStage(s) ==
                  ServantsAttendanceService.normalizeStage(preferred),
            )) {
          _selectedStage = preferred;
        } else if (_selectedStage.trim().isEmpty && stages.isNotEmpty) {
          _selectedStage = stages.first;
        } else if (stages.isEmpty) {
          _selectedStage = '';
        }
        _restartMainStreams();
      });
    } else {
      _availableStages = [user.stage];
      _selectedStage = user.stage;
      await _restartMainStreams();
    }
  }

  Future<void> _restartMainStreams() async {
    final user = _currentUser;
    if (user == null) return;

    _error = null;
    _needsAutoEditModeSync = true;
    _setLoadingServants(true);
    _setLoadingAttendance(true);

    await _servantsSub?.cancel();
    await _attendanceSub?.cancel();

    _servantsSub = _service
        .watchServants(
          requesterRole: user.role.value,
          requesterStage: user.stage,
          selectedStage: _selectedStage,
          requesterUserId: user.id,
        )
        .listen(
          (list) {
            _servants = list;
            _setLoadingServants(false);
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _setLoadingServants(false);
            notifyListeners();
          },
        );

    _attendanceSub = _service
        .watchAttendanceForDate(
          date: _selectedDate,
          requesterRole: user.role.value,
          requesterStage: user.stage,
          selectedStage: _selectedStage,
          requesterUserId: user.id,
        )
        .listen(
          (list) {
            _attendanceByServantId = {
              for (final item in list) item.servantId: item,
            };
            _setLoadingAttendance(false);
            _syncEditMode();
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _setLoadingAttendance(false);
            notifyListeners();
          },
        );
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void previousDay() =>
      setDate(_selectedDate.subtract(const Duration(days: 1)));
  void nextDay() => setDate(_selectedDate.add(const Duration(days: 1)));

  Future<void> setDate(DateTime value) async {
    _selectedDate = DateTime(value.year, value.month, value.day);
    _draft = {};
    _needsAutoEditModeSync = true;
    await _restartMainStreams();
  }

  Future<void> setSelectedStage(String stage) async {
    if (!isManager) return;
    if (_selectedStage.trim() == stage.trim()) return;
    _selectedStage = stage;
    _draft = {};
    _needsAutoEditModeSync = true;
    await _restartMainStreams();
  }

  bool attendedForServant(String servantId) {
    if (_draft.containsKey(servantId)) return _draft[servantId] ?? false;
    return _attendanceByServantId[servantId]?.attended ?? false;
  }

  void toggleAttendance(String servantId) {
    if (!canEdit || !_isEditMode) return;
    final current = attendedForServant(servantId);
    _draft[servantId] = !current;
    notifyListeners();
  }

  void enableEditMode() {
    if (!canEdit) return;
    _isEditMode = true;
    _needsAutoEditModeSync = false;
    notifyListeners();
  }

  void disableEditMode() {
    if (!_isEditMode) return;
    _isEditMode = false;
    _needsAutoEditModeSync = false;
    notifyListeners();
  }

  Future<void> saveAttendance() async {
    final user = _currentUser;
    if (user == null) throw Exception('User not ready.');
    if (!canEdit) throw Exception('You are not allowed to save attendance.');
    if (_selectedStage.trim().isEmpty)
      throw Exception('Stage is not selected.');
    if (_servants.isEmpty) throw Exception('No servants loaded.');

    _isSaving = true;
    notifyListeners();

    try {
      final attendanceByServantId = <String, bool>{};
      for (final s in _servants) {
        attendanceByServantId[s.id] = attendedForServant(s.id);
      }

      await _service.saveAttendance(
        stage: _selectedStage,
        date: _selectedDate,
        servants: _servants,
        attendedByServantId: attendanceByServantId,
        createdBy: user.name,
      );

      _draft = {};
      _isEditMode = false;
      _needsAutoEditModeSync = false;
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

  void _setLoadingServants(bool value) {
    if (_isLoadingServants == value) return;
    _isLoadingServants = value;
  }

  void _setLoadingAttendance(bool value) {
    if (_isLoadingAttendance == value) return;
    _isLoadingAttendance = value;
  }

  void _syncEditMode() {
    if (!_needsAutoEditModeSync) return;
    if (!canEdit) {
      _isEditMode = false;
      _needsAutoEditModeSync = false;
      return;
    }

    // First time for this day: edit ON. If attendance exists: edit OFF.
    _isEditMode = !attendanceExists;
    _needsAutoEditModeSync = false;
  }

  @override
  void dispose() {
    _servantsSub?.cancel();
    _attendanceSub?.cancel();
    _stagesSub?.cancel();
    super.dispose();
  }
}
