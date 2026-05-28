import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:summerschool/firebase_options.dart';
import 'package:summerschool/models/user_model.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM][Background] messageId=${message.messageId}');
  debugPrint('[FCM][Background] title=${message.notification?.title}');
  debugPrint('[FCM][Background] body=${message.notification?.body}');
  debugPrint('[FCM][Background] data=${message.data}');
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  factory FcmService() => instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _subscribedTopics = <String>{};

  bool _initialized = false;
  bool _listenersRegistered = false;
  String? _currentUserId;
  String? _currentToken;
  String? _permissionStatus;
  String? _lastReceivedMessage;
  DateTime? _lastReceivedAt;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'default_channel',
    'Default Channel',
    description: 'Foreground notifications for Summer School',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('[FCM] Initializing...');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _setupLocalNotifications();
    await _requestPermission();
    _registerListenersOnce();

    _initialized = true;
    debugPrint('[FCM] Initialized');
  }

  Future<void> _setupLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[FCM][LocalNotification] payload=${response.payload}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
    debugPrint('[FCM] Local notifications ready on ${_channel.id}');
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _permissionStatus = settings.authorizationStatus.name;
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus.name}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _registerListenersOnce() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('[FCM][onMessage] fired');
      await _handleIncomingMessage(message, source: 'onMessage');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM][onMessageOpenedApp] fired');
      _updateDebugState(message);
      _logMessage('onMessageOpenedApp', message);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _currentToken = token;
      debugPrint('[FCM][onTokenRefresh] token=$token');
      _saveTokenIfPossible(token);
    });

    debugPrint('[FCM] FCM listeners registered once');
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    _currentToken = token;
    debugPrint('[FCM] Current token: $token');
    return token;
  }

  Future<void> syncTokenWithUser(UserModel user) async {
    _currentUserId = user.id;

    final token = await getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[FCM] Token empty, not saving to Firestore');
      return;
    }

    await _firestore.collection('users').doc(user.id).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[FCM] Token saved to Firestore for uid=${user.id}');
  }

  Future<void> clearTokenForUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Cleared token for uid=$userId');
    } catch (error) {
      debugPrint('[FCM] Failed to clear token for uid=$userId: $error');
    } finally {
      if (_currentUserId == userId) {
        _currentUserId = null;
      }
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    final sanitized = _sanitizeTopic(topic);
    if (sanitized.isEmpty) return;

    await _messaging.subscribeToTopic(sanitized);
    _subscribedTopics.add(sanitized);
    debugPrint('[FCM] Subscribed to topic: $sanitized');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final sanitized = _sanitizeTopic(topic);
    if (sanitized.isEmpty) return;

    await _messaging.unsubscribeFromTopic(sanitized);
    _subscribedTopics.remove(sanitized);
    debugPrint('[FCM] Unsubscribed from topic: $sanitized');
  }

  Future<void> subscribeToUserTopics(String role, String? stage) async {
    final topics = <String>{'all'};

    final normalizedRole = _normalizeTopic(role);
    if (normalizedRole.isNotEmpty) {
      topics.add(normalizedRole);
    }

    if (normalizedRole == 'manager') {
      topics.add('managers');
    } else if (normalizedRole == 'member_manager') {
      topics.add('member_managers');
    } else if (normalizedRole == 'member') {
      topics.add('members');
    }

    final sanitizedStage = _sanitizeStage(stage);
    if (sanitizedStage != null) {
      topics.add(sanitizedStage);
    }

    await unsubscribeFromTopics();
    for (final topic in topics) {
      await subscribeToTopic(topic);
    }
  }

  Future<void> unsubscribeFromTopics() async {
    if (_subscribedTopics.isEmpty) return;

    final topics = List<String>.from(_subscribedTopics);
    for (final topic in topics) {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    }
    _subscribedTopics.clear();
  }

  Future<void> _handleIncomingMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    _updateDebugState(message);
    _logMessage(source, message);

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? '',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _logMessage(String source, RemoteMessage message) {
    debugPrint('[FCM][$source] messageId=${message.messageId}');
    debugPrint('[FCM][$source] title=${message.notification?.title}');
    debugPrint('[FCM][$source] body=${message.notification?.body}');
    debugPrint('[FCM][$source] data=${message.data}');
    debugPrint('[FCM][$source] full=${jsonEncode(_messageDump(message))}');
  }

  void _updateDebugState(RemoteMessage message) {
    _lastReceivedAt = DateTime.now();
    _lastReceivedMessage =
        'title=${message.notification?.title}, body=${message.notification?.body}, data=${message.data}';
  }

  Map<String, dynamic> _messageDump(RemoteMessage message) {
    return <String, dynamic>{
      'messageId': message.messageId,
      'from': message.from,
      'sentTime': message.sentTime?.toIso8601String(),
      'notification': {
        'title': message.notification?.title,
        'body': message.notification?.body,
      },
      'data': message.data,
    };
  }

  Future<void> showTestNotification({
    String title = 'Test Notification',
    String body = 'This is a local notification test.',
  }) async {
    await _localNotifications.show(
      999001,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'test_local_notification'}),
    );
  }

  Future<void> simulateIncomingMessage({
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final message = RemoteMessage(
      messageId: 'simulated-${DateTime.now().millisecondsSinceEpoch}',
      notification: RemoteNotification(title: title, body: body),
      data: data ?? <String, dynamic>{'simulated': 'true'},
    );

    debugPrint('[FCM] Simulating incoming message');
    await _handleIncomingMessage(message, source: 'simulate');
  }

  Future<void> _saveTokenIfPossible(String token) async {
    final userId = _currentUserId;
    if (userId == null || token.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Refreshed token saved for uid=$userId');
    } catch (error) {
      debugPrint('[FCM] Failed to save refreshed token: $error');
    }
  }

  String? get currentToken => _currentToken;
  String? get permissionStatus => _permissionStatus;
  String? get lastReceivedMessage => _lastReceivedMessage;
  DateTime? get lastReceivedAt => _lastReceivedAt;
  List<String> get subscribedTopics =>
      List<String>.unmodifiable(_subscribedTopics);

  String _normalizeTopic(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  String _sanitizeTopic(String value) {
    return _normalizeTopic(value).replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
  }

  String? _sanitizeStage(String? stage) {
    if (stage == null) return null;

    final cleaned = stage.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '_',
    );
    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('stage_')) return cleaned;
    return 'stage_$cleaned';
  }
}
