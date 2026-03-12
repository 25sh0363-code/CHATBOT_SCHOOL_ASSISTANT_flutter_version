import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _examChannelId = 'exam_reminders_channel';
  static const String _focusChannelId = 'focus_session_channel';
  static const String _examChannelName = 'Exam Reminders';
  static const String _focusChannelName = 'Focus Sessions';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    final macPlugin = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    bool focusPopup = false,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      _details(
        channelId: _focusChannelId,
        channelName: _focusChannelName,
        focusPopup: focusPopup,
      ),
    );
  }

  Future<void> scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    bool focusChannel = false,
  }) async {
    await initialize();
    final target = tz.TZDateTime.from(at, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      target,
      _details(
        channelId: focusChannel ? _focusChannelId : _examChannelId,
        channelName: focusChannel ? _focusChannelName : _examChannelName,
        focusPopup: focusChannel,
      ),
      androidScheduleMode: focusChannel
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  Future<void> scheduleDailyExamReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      _details(channelId: _examChannelId, channelName: _examChannelName),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  NotificationDetails _details({
    required String channelId,
    required String channelName,
    bool focusPopup = false,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: focusPopup
            ? 'Full-screen focus session alerts'
            : 'Important exam reminder alerts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        styleInformation: focusPopup
            ? const BigTextStyleInformation(
                'Great work. Time for a short break.',
                contentTitle: 'Focus Session Complete',
                summaryText: 'Tap to return to your study session',
              )
            : null,
        fullScreenIntent: focusPopup,
        category: focusPopup ? AndroidNotificationCategory.alarm : null,
        visibility: NotificationVisibility.public,
        ticker: focusPopup ? 'Focus session complete' : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  static int stableIdFromText(String value, {required int offset}) {
    var hash = 0;
    for (final rune in value.runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    return offset + (hash % 900000);
  }

  bool get isApple => Platform.isIOS || Platform.isMacOS;
}
