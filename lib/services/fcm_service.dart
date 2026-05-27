import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:summerschool/firebase_options.dart';

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
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _subscribedTopics = <String>{};

  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'summer_school_notifications',
    'Summer School Notifications',
    description: 'Foreground notifications for Summer School',
    importance: Importance.high,
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
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    await _requestPermissions();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
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

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    debugPrint('[FCM] Token generated: $token');
    return token;
  }

  Future<void> subscribeToUserTopics(String role, String? stage) async {
    final topics = <String>{'all_users'};

    final normalizedRole = _normalizeTopic(role);
    if (normalizedRole.isNotEmpty) {
      topics.add(normalizedRole);
    }

    final sanitizedStage = _sanitizeStage(stage);
    if (sanitizedStage != null) {
      topics.add(sanitizedStage);
    }

    await unsubscribeFromTopics();

    for (final topic in topics) {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    }

    _subscribedTopics
      ..clear()
      ..addAll(topics);
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
    debugPrint('[FCM][Foreground] ${message.notification?.title}');

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
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('[FCM][Open] ${message.notification?.title}');
  }

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
