import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:summerschool/models/weekly_schedule_item_model.dart';
import 'package:summerschool/services/weekly_schedule_service.dart';

class WeeklyScheduleProvider extends ChangeNotifier {
  WeeklyScheduleProvider({required WeeklyScheduleService service})
    : _service = service;

  final WeeklyScheduleService _service;

  List<WeeklyScheduleItemModel> _items = [];
  bool _isLoading = false;
  String? _error;
  String _selectedDay = WeeklyScheduleDays.sunday;
  String _currentStage = '';

  StreamSubscription<List<WeeklyScheduleItemModel>>? _sub;

  List<WeeklyScheduleItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedDay => _selectedDay;

  String generateId() => _service.generateId();

  Future<void> initialize({required String stage}) async {
    _currentStage = stage;
    await _startListening();
  }

  Future<void> selectDay(String day) async {
    if (_selectedDay == day) return;
    _selectedDay = day;
    debugPrint('[WeeklySchedule] selected day changed -> $day');
    notifyListeners();
    await _startListening();
  }

  Future<void> addItem(WeeklyScheduleItemModel item) async {
    _setLoading(true);
    try {
      await _service.addItem(item);
      _error = null;
      debugPrint('[WeeklySchedule] item added id=${item.id}');
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateItem(WeeklyScheduleItemModel item) async {
    _setLoading(true);
    try {
      await _service.updateItem(item);
      _error = null;
      debugPrint('[WeeklySchedule] item updated id=${item.id}');
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteItem(String id) async {
    _setLoading(true);
    try {
      await _service.deleteItem(id);
      _error = null;
      debugPrint('[WeeklySchedule] item deleted id=$id');
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disposeListening() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _startListening() async {
    if (_currentStage.trim().isEmpty) {
      _items = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    await _sub?.cancel();

    _sub = _service
        .watchWeeklySchedule(stage: _currentStage, day: _selectedDay)
        .listen(
          (items) {
            _items = items;
            _error = null;
            _setLoading(false);
            debugPrint(
              '[WeeklySchedule] schedule loaded stage="$_currentStage" day="$_selectedDay" count=${items.length}',
            );
          },
          onError: (e) {
            _error = e.toString();
            _setLoading(false);
          },
        );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class WeeklyScheduleDays {
  static const String sunday = 'sunday';
  static const String wednesday = 'wednesday';

  static const List<String> values = [sunday, wednesday];

  static String arabicLabel(String value) {
    switch (value) {
      case sunday:
        return 'Sunday';
      case wednesday:
        return 'Wednesday';
      default:
        return value;
    }
  }
}
