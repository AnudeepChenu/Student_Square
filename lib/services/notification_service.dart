import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showClassAlert(String subject, String room, String time) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'class_alerts_channel',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes 20 minutes prior',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      'Upcoming Class in 20 min: $subject',
      'Location: $room | Time: $time',
      notificationDetails,
    );
  }
}