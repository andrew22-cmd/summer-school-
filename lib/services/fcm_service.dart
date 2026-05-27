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
  debugPrint(
    '[FCM][Background] id=${message.messageId} title=${message.notification?.title}',
  );
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

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint(
          '[FCM][LocalNotification] tapped payload=${response.payload}',
        );
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    // ensure the Android channel exists before registering listeners
    debugPrint('[FCM] Creating Android notification channel: ${_channel.id}');
    await androidPlugin?.createNotificationChannel(_channel);
    final androidPermissionGranted = await androidPlugin
        ?.requestNotificationsPermission();
    debugPrint(
      '[FCM] Android notification permission granted: ${androidPermissionGranted ?? false}',
    );

    await _requestPermissions();

    debugPrint('[FCM] Registering FirebaseMessaging.onMessage listener');
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM][onMessage] fired');
      _handleForegroundMessage(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[FCM] Token refreshed: $token');
      _saveTokenIfPossible(token);
    });

    await _subscribeToTopics(<String>[
      'all',
      'all_users',
      'members',
      'member_managers',
      'managers',
    ]);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] getInitialMessage returned a message');
      _handleOpenedMessage(initialMessage);
    } else {
      debugPrint('[FCM] getInitialMessage returned null');
    }

    _initialized = true;
    debugPrint('[FCM] Initialized');
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _permissionStatus = settings.authorizationStatus.name;
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '[FCM] iOS/APNs permission status: ${settings.authorizationStatus}',
    );
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    _currentToken = token;
    debugPrint('FCM TOKEN: $token');
    debugPrint('[FCM] Token generated: $token');
    return token;
  }

  Future<void> syncTokenWithUser(UserModel user) async {
    _currentUserId = user.id;

    final token = await getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[FCM] Token is null/empty, not saving to Firestore');
      return;
    }

    await _firestore.collection('users').doc(user.id).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[FCM] Token saved to Firestore for uid=${user.id}');
    debugPrint('FCM token saved successfully');
  }

  Future<void> clearTokenForUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Cleared token fields for uid=$userId');
    } catch (error) {
      debugPrint('[FCM] Failed to clear token for uid=$userId: $error');
    } finally {
      if (_currentUserId == userId) {
        _currentUserId = null;
      }
    }
  }

  Future<void> subscribeToUserTopics(String role, String? stage) async {
    final topics = <String>{'all', 'all_users'};

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

    await _subscribeToTopics(topics.toList());

    _subscribedTopics
      ..clear()
      ..addAll(topics);
  }

  Future<void> _subscribeToTopics(List<String> topics) async {
    for (final topic in topics) {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
      debugPrint('[FCM] Subscribed to topic: $topic');
    }
  }

  Future<void> unsubscribeFromTopics() async {
    if (_subscribedTopics.isEmpty) return;

    for (final topic in _subscribedTopics) {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    }

    _subscribedTopics.clear();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM][Foreground] onMessage handler start');
    try {
      final Map<String, dynamic> dump = {
        'messageId': message.messageId,
        'from': message.from,
        'sentTime': message.sentTime?.toIso8601String(),
        'notification': {
          'title': message.notification?.title,
          'body': message.notification?.body,
        },
        'data': message.data,
      };
      debugPrint('[FCM][Foreground] full message: ${jsonEncode(dump)}');

      debugPrint('[FCM][Foreground] title=${message.notification?.title}');
      debugPrint('[FCM][Foreground] body=${message.notification?.body}');
      debugPrint('[FCM][Foreground] data=${message.data}');

      _lastReceivedAt = DateTime.now();
      _lastReceivedMessage =
          'title=${message.notification?.title}, body=${message.notification?.body}, data=${message.data}';
    } catch (e, st) {
      debugPrint('[FCM][Foreground] Error while processing message: $e');
      debugPrint(st.toString());
    }

    final notification = message.notification;
    if (notification != null) {
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
  }

  /// Simulate an incoming FCM message (useful for debugging)
  Future<void> simulateIncomingMessage({
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final remoteNotification = RemoteNotification(title: title, body: body);
    final message = RemoteMessage(
      messageId: 'simulated-${DateTime.now().microsecondsSinceEpoch}',
      notification: remoteNotification,
      data: data ?? <String, dynamic>{'simulated': 'true'},
    );

    debugPrint(
      '[FCM] Simulating incoming message: title=$title body=$body data=$data',
    );
    await _handleForegroundMessage(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('[FCM][Open] messageId=${message.messageId}');
    debugPrint('[FCM][Open] title=${message.notification?.title}');
    debugPrint('[FCM][Open] body=${message.notification?.body}');
    debugPrint('[FCM][Open] data=${message.data}');
    _lastReceivedMessage =
        'title=${message.notification?.title}, body=${message.notification?.body}, data=${message.data}';
  }

  Future<void> showTestNotification({
    String title = 'Test Local Notification',
    String body = 'This is a local notification test.',
  }) async {
    debugPrint('[FCM] Showing test local notification');
    await _localNotifications.show(
      999001,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'test_local_notification'}),
    );
  }

  Future<void> _saveTokenIfPossible(String token) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      debugPrint('[FCM] No active user, skipping token refresh save');
      return;
    }

    if (token.isEmpty) {
      debugPrint('[FCM] Refreshed token empty, skipping save');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Refreshed token saved for uid=$userId');
    } catch (error) {
      debugPrint(
        '[FCM] Failed to save refreshed token for uid=$userId: $error',
      );
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
