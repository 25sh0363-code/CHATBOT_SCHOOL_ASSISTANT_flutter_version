import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/timetable_entry.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _timetableChannelId = 'timetable_reminders';
  static const String _timetableChannelName = 'Timetable Reminders';
  static const String _timetableChannelDescription =
      'Notifications for upcoming timetable classes';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    // Timezone setup is required for zoned notifications.
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> syncTimetableNotifications(List<TimetableEntry> entries) async {
    await initialize();

    await _plugin.cancelAll();

    final now = DateTime.now();
    for (final entry in entries) {
      final scheduleTime = _buildScheduleDateTime(entry);
      if (scheduleTime == null || !scheduleTime.isAfter(now)) {
        // Class reminder is skipped if class start time is in the past.
      } else {
        final notificationId = _notificationIdForEntry(entry.id, suffix: 'class');
        final tzDate = tz.TZDateTime.from(scheduleTime, tz.local);

        await _plugin.zonedSchedule(
          notificationId,
          'Upcoming class: ${entry.subject}',
          'Starts at ${entry.startTime}${entry.notes.isEmpty ? '' : ' - ${entry.notes}'}',
          tzDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _timetableChannelId,
              _timetableChannelName,
              channelDescription: _timetableChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      final homeworkTime = _buildHomeworkReminderDateTime(entry);
      if (homeworkTime == null || !homeworkTime.isAfter(now)) {
        continue;
      }

      final homeworkId = _notificationIdForEntry(entry.id, suffix: 'homework');
      final homeworkTzDate = tz.TZDateTime.from(homeworkTime, tz.local);
      await _plugin.zonedSchedule(
        homeworkId,
        'Homework reminder: ${entry.subject}',
        entry.homeworkTask.isEmpty
            ? 'Time to finish your homework.'
            : entry.homeworkTask,
        homeworkTzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _timetableChannelId,
            _timetableChannelName,
            channelDescription: _timetableChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  DateTime? _buildHomeworkReminderDateTime(TimetableEntry entry) {
    if (entry.homeworkReminderTime.trim().isEmpty) {
      return null;
    }
    final parsedTime = _parse24HourTime(entry.homeworkReminderTime);
    if (parsedTime == null) {
      return null;
    }

    return DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
      parsedTime.$1,
      parsedTime.$2,
    );
  }

  DateTime? _buildScheduleDateTime(TimetableEntry entry) {
    final parsedTime = _parse24HourTime(entry.startTime);
    if (parsedTime == null) {
      return null;
    }

    return DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
      parsedTime.$1,
      parsedTime.$2,
    );
  }

  (int, int)? _parse24HourTime(String input) {
    final parts = input.trim().split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour, minute);
  }

  int _notificationIdForEntry(String id, {required String suffix}) {
    final key = '$id:$suffix';
    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
