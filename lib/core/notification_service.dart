import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('----------------------------------------------------');
  debugPrint(
      '📦 [NOTIFICATION  PAYLOAD]:\n${const JsonEncoder.withIndent('  ').convert(message.data)}');
  debugPrint('----------------------------------------------------');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging & Local Notification heads-up banner
  Future<void> initialize() async {
    // 1. Request notification permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 [NOTIFICATION] Permission granted!');
    } else {
      debugPrint('⚠️ [NOTIFICATION] Permission declined or not granted');
    }

    // 2. Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    // 3. Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final title =
          notification?.title ?? message.data['title'] ?? 'New Message';
      final body = notification?.body ?? message.data['body'] ?? '';

      showNotification(
        title: title,
        body: body,
        soundName: message.data['sound'] ?? 'new_notification',
        dataPayload: message.data,
      );
    });

    // 5. Fetch & log FCM token
    final token = await getToken();
    debugPrint('🔑 [FCM TOKEN] $token');
  }

  /// Helper to get current FCM token safely
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('⚠️ [FCM TOKEN ERROR] $e');
      return null;
    }
  }

  /// Show a local heads-up notification banner with custom audio support
  Future<void> showNotification({
    required String title,
    required String body,
    String? soundName,
    Map<String, dynamic>? dataPayload,
  }) async {
    // Format audio resource name (e.g. 'new_Notification.wav' -> 'new_notification')
    String? rawAudioName =
        soundName?.replaceAll('.wav', '').replaceAll('.mp3', '').toLowerCase();
    if (rawAudioName == null || rawAudioName.isEmpty) {
      rawAudioName = 'new_notification';
    }

    final channelId = 'custom_sound_channel_$rawAudioName';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      'Custom Audio Notifications ($rawAudioName)',
      channelDescription: 'Notification channel for $rawAudioName audio sound',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      sound: RawResourceAndroidNotificationSound(rawAudioName),
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payloadString = dataPayload != null ? jsonEncode(dataPayload) : null;

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payloadString,
    );
  }
}
