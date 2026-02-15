import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for local push notifications.
///
/// Shows notifications when AI detects interesting ideas
/// while the app is running in the background.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification plugin and request iOS permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request iOS permissions explicitly
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  /// Show a notification when AI detects an interesting idea.
  Future<void> showInsightNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'meetmind_insights',
        'Meeting Insights',
        channelDescription: 'AI-detected insights from your meetings',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // When user taps notification, app comes to foreground automatically.
    // No extra routing needed — meeting screen is already active.
  }
}
