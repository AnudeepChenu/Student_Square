import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationHelper {
  static Future<void> scheduleClassNotifications(List<Map<String, dynamic>> timetable) async {
    tz.initializeTimeZones();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.cancelAll();

    for (int i = 0; i < timetable.length; i++) {
      final item = timetable[i];
      final dayStr = item['day']?.toString().toLowerCase() ?? '';
      final timeStr = item['time']?.toString() ?? '';
      final rawSubject = item['subject']?.toString() ?? 'Class';

      if (timeStr.isEmpty) continue;

      final startTimeClean = timeStr.split('-')[0].trim();
      int targetWeekday = _getDayInt(dayStr);
      if (targetWeekday == -1) continue;

      tz.TZDateTime scheduledDate = _nextInstanceOfDayAndTime(targetWeekday, startTimeClean);
      scheduledDate = scheduledDate.subtract(const Duration(minutes: 15));

      if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        final parsed = _parseDetails(rawSubject);
        final subjectName = parsed['subject']!;
        final roomNumber = parsed['room']!;

        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'student_square_class_reminders',
          'Class Reminders',
          channelDescription: 'Reminders 15 minutes before classes',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'app_logo',
        );

        await flutterLocalNotificationsPlugin.zonedSchedule(
          i,
          'Next class at $startTimeClean',
          '$subjectName (${roomNumber.isEmpty ? "N/A" : roomNumber})',
          scheduledDate,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static Map<String, String> _parseDetails(String rawSubject) {
    String subject = rawSubject;
    String room = '';

    try {
      if (rawSubject.contains(':')) {
        var parts = rawSubject.split(':');
        subject = parts[0].trim();

        if (parts.length > 1) {
          String secondPart = parts[1].trim();
          RegExp roomReg = RegExp(r'\(([^)]+)\)');
          var match = roomReg.firstMatch(secondPart);
          if (match != null) {
            String roomBlock = match.group(1) ?? '';
            room = roomBlock.split('-').first.trim();
          }
        }
      }
    } catch (_) {
      subject = rawSubject;
    }

    return {
      'subject': subject,
      'room': room,
    };
  }

  static int _getDayInt(String day) {
    switch (day.trim().toLowerCase()) {
      case 'monday': return DateTime.monday;
      case 'tuesday': return DateTime.tuesday;
      case 'wednesday': return DateTime.wednesday;
      case 'thursday': return DateTime.thursday;
      case 'friday': return DateTime.friday;
      case 'saturday': return DateTime.saturday;
      case 'sunday': return DateTime.sunday;
      default: return -1;
    }
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int weekday, String timeString) {
    final now = tz.TZDateTime.now(tz.local);
    final upper = timeString.toUpperCase();
    bool isPM = upper.contains('PM');
    bool isAM = upper.contains('AM');
    String clean = upper.replaceAll('AM', '').replaceAll('PM', '').trim();
    var parts = clean.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts.length > 1 ? parts[1] : '0');

    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}