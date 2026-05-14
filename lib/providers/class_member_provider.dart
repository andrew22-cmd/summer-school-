import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/services/class_member_service.dart';
import 'package:summerschool/services/points_service.dart';

class ClassMemberProvider extends ChangeNotifier {
  ClassMemberProvider({
    required ClassMemberService service,
    PointsService? pointsService,
  }) : _service = service,
       _pointsService = pointsService ?? PointsService();

  final ClassMemberService _service;
  final PointsService _pointsService;

  List<ClassMemberModel> _members = [];
  bool _isLoading = false;
  String? _error;
  String _search = '';
  String _stageFilter = '';
  StreamSubscription<List<ClassMemberModel>>? _sub;

  // ================== ADD THIS ==================
  String? _currentStage;
  // ==============================================

  List<ClassMemberModel> get members {
    final q = _search.trim().toLowerCase();
    final stage = _stageFilter.trim();

    String _normalize(String s) => s.replaceAll(' ', '').toLowerCase();

    final filtered = _members.where((m) {
      final searchOk = q.isEmpty || m.name.toLowerCase().contains(q);

      final stageOk =
          stage.isEmpty || _normalize(m.stage) == _normalize(stage);

      return searchOk && stageOk;
    }).toList();

    if (q.isNotEmpty || stage.isNotEmpty) {
      debugPrint(
        '[ClassMemberProvider][members] search="$q" stageFilter="$stage" total=${_members.length} filtered=${filtered.length}',
      );

      for (final m in _members) {
        final searchOk = q.isEmpty || m.name.toLowerCase().contains(q);

        final stageOk =
            stage.isEmpty || _normalize(m.stage) == _normalize(stage);

        if (!searchOk || !stageOk) {
          debugPrint(
            '[ClassMemberProvider][members] ignored name="${m.name}" stage="${m.stage}" stage_norm="${_normalize(m.stage)}" reason=${!searchOk ? 'search' : 'stage'}',
          );
        }
      }
    }

    return filtered;
  }

  /// Returns all members without filtering
  /// Use this when you need the raw list (e.g., for student selection dropdowns)
  List<ClassMemberModel> get allMembers => _members;

  List<String> get availableStages {
    final set = _members
        .map((m) => m.stage.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    final list = set.toList()..sort();

    return list;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get stageFilter => _stageFilter;

  Future<void> startListening(String stage) async {
    final normalized = ClassMemberService.normalizeStage(stage);

    // ================== ADD THIS ==================
    if (_currentStage == normalized && _sub != null) {
      debugPrint(
        '[STREAM UPDATE] Already listening to same stage "$normalized"',
      );
      return;
    }

    _currentStage = normalized;
    // ==============================================

    debugPrint(
      '[STREAM UPDATE] ClassMemberProvider.startListening() requestedStage="$stage" normalized="$normalized"',
    );

    if (normalized.isEmpty) {
      debugPrint(
        '[STREAM UPDATE] ClassMemberProvider empty normalized stage. Skipping Firestore query and waiting for a valid stage.',
      );

      _members = [];
      _setLoading(false);
      notifyListeners();

      return;
    }

    _setLoading(true);
    _error = null;

    await _sub?.cancel();

    _sub = _service.watchMembersForStage(stage).listen(
      (list) {
        debugPrint(
          '[STREAM UPDATE] ClassMemberProvider snapshot received count=${list.length}',
        );

        for (final m in list) {
          debugPrint(
            '[STREAM] ClassMemberProvider member name="${m.name}" stage="${m.stage}" totalPoints=${m.totalPoints}',
          );
        }

        _members = list;

        _setLoading(false);

        debugPrint(
          '[PROVIDER NOTIFY] ClassMemberProvider calling notifyListeners() - UI should rebuild',
        );

        notifyListeners();

        debugPrint('[PROVIDER NOTIFY] ✓ notifyListeners() completed');
      },
      onError: (e) {
        debugPrint('[STREAM UPDATE] ClassMemberProvider stream error=$e');

        _error = e.toString();

        _setLoading(false);

        notifyListeners();
      },
    );
  }

  Future<void> startListeningAllMembers() async {
    debugPrint(
      '[STREAM UPDATE] ClassMemberProvider.startListeningAllMembers() starting',
    );

    _setLoading(true);

    _error = null;

    await _sub?.cancel();

    _sub = _service.watchAllMembers().listen(
      (list) {
        debugPrint(
          '[STREAM UPDATE] ClassMemberProvider watchAllMembers snapshot received count=${list.length}',
        );

        _members = list;

        _setLoading(false);

        debugPrint(
          '[PROVIDER NOTIFY] ClassMemberProvider calling notifyListeners() for all members',
        );

        notifyListeners();

        debugPrint('[PROVIDER NOTIFY] ✓ notifyListeners() completed');
      },
      onError: (e) {
        debugPrint(
          '[STREAM UPDATE] ClassMemberProvider watchAllMembers error=$e',
        );

        _error = e.toString();

        _setLoading(false);

        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await _sub?.cancel();

    _sub = null;

    // ================== ADD THIS ==================
    _currentStage = null;
    // ==============================================
  }

  void setSearch(String value) {
    _search = value;

    debugPrint(
      '[PROVIDER NOTIFY] ClassMemberProvider.setSearch("$value") - triggering rebuild',
    );

    notifyListeners();
  }

  void setStageFilter(String value) {
    _stageFilter = value;

    debugPrint(
      '[PROVIDER NOTIFY] ClassMemberProvider.setStageFilter("$value") - triggering rebuild',
    );

    notifyListeners();
  }

  Future<ClassMemberModel> addMember(ClassMemberModel member) async {
    return await _service.addMember(member);
  }

  Future<int> migrateStageNorm() async {
    final count = await _service.migrateAddStageNormAll();

    // refresh data after migration
    await startListeningAllMembers();

    return count;
  }

  Future<void> updateMember(String id, Map<String, dynamic> updates) async {
    await _service.updateMember(id, updates);
  }

  Future<void> deleteMember(String id) async {
    await _service.deleteMember(id);
  }

  /// Add points to a student and refresh all members data
  Future<void> addPoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdBy,
  }) async {
    debugPrint(
      '[ADD POINTS] ClassMemberProvider.addPoints() Adding $points points to ${student.name} reason="$reason"',
    );

    try {
      await _pointsService.addPoints(
        student: student,
        points: points,
        reason: reason,
        createdBy: createdBy,
      );

      debugPrint(
        '[ADD POINTS] ✓ Transaction completed. Firestore snapshot will trigger notifyListeners()',
      );
    } catch (e) {
      debugPrint('[ADD POINTS] ❌ Error: $e');

      rethrow;
    }
  }

  /// Remove points from a student and refresh all members data
  Future<void> removePoints({
    required ClassMemberModel student,
    required int points,
    required String reason,
    required String createdBy,
  }) async {
    debugPrint(
      '[REMOVE POINTS] ClassMemberProvider.removePoints() Removing $points points from ${student.name} reason="$reason"',
    );

    try {
      await _pointsService.removePoints(
        student: student,
        points: points,
        reason: reason,
        createdBy: createdBy,
      );

      debugPrint(
        '[REMOVE POINTS] ✓ Transaction completed. Firestore snapshot will trigger notifyListeners()',
      );
    } catch (e) {
      debugPrint('[REMOVE POINTS] ❌ Error: $e');

      rethrow;
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;

    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();

    super.dispose();
  }
}