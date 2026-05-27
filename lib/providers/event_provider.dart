import 'package:flutter/material.dart';
import 'dart:async';
import 'package:summerschool/models/event_model.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/services/event_service.dart';

class EventProvider extends ChangeNotifier {
  EventProvider(this._service);

  final EventService _service;
  Stream<List<EventModel>>? _subscriptionStream;
  StreamSubscription<List<EventModel>>? _subscription;

  List<EventModel> _events = [];
  bool _isLoading = false;
  String? _error;

  List<EventModel> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<EventModel>> startListening() {
    _subscriptionStream = _service.watchEvents();
    _subscription = _subscriptionStream?.listen(
      (list) {
        _events = list;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
    return _subscriptionStream!;
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _subscriptionStream = null;
  }

  Future<void> refresh() async {
    _setLoading(true);
    try {
      final list = await _service.watchEvents().first;
      _events = list;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addEvent(EventModel event, {UserModel? senderUserModel}) async {
    _setLoading(true);
    try {
      await _service.createEvent(event, senderUserModel: senderUserModel);
      _error = null;
      // refresh local list will be handled by stream listener
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await _service.updateEvent(id, data);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteEvent(String id) async {
    _setLoading(true);
    try {
      await _service.deleteEvent(id);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<int> deleteExpiredEvents() async {
    _setLoading(true);
    try {
      final removed = await _service.deleteExpiredEvents();
      _error = null;
      return removed;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
