import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
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
  bool _notificationsEnabled = false;

  bool get notificationsEnabled {
    // ignore: avoid_print
    debugPrint('[NotificationService] notificationsEnabled getter: $_notificationsEnabled');
    return _notificationsEnabled;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
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
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _examChannelId,
          _examChannelName,
          description: 'Important exam reminder alerts',
          importance: Importance.max,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _focusChannelId,
          _focusChannelName,
          description: 'Full-screen focus session alerts',
          importance: Importance.max,
        ),
      );
      debugPrint('[NotificationService] Notification channels created');
      final enabled = await androidPlugin?.areNotificationsEnabled();
      final granted = await androidPlugin?.requestNotificationsPermission();
      if (enabled == true || granted == true) {
        _notificationsEnabled = true;
      } else if (enabled == null && granted == null) {
        // Fallback: if both are unavailable, assume enabled
        _notificationsEnabled = true;
      } else {
        _notificationsEnabled = false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to create channels or check permissions: $e');
      // Fallback: if error, assume enabled
      _notificationsEnabled = true;
    }
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestFullScreenIntentPermission();
    } catch (_) {}

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    try {
      await iosPlugin?.requestPermissions(
          alert: true, badge: true, sound: true);
    } catch (_) {}

    final macPlugin = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    try {
      await macPlugin?.requestPermissions(
          alert: true, badge: true, sound: true);
    } catch (_) {}

    _initialized = true;
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    bool focusPopup = false,
  }) async {
    await initialize();
    if (!_notificationsEnabled) {
        debugPrint('[NotificationService] Notifications not enabled, skipping showNow');
      return;
    }
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
      debugPrint('[NotificationService] showNow called: id=$id, title=$title, body=$body');
  }

  Future<void> scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    bool focusChannel = false,
  }) async {
    await initialize();
    debugPrint('[NotificationService] scheduleOneTime ENTRY: id=$id, title=$title, at=$at');
    debugPrint('[NotificationService] scheduleOneTime: Calling zonedSchedule');
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        _details(
          channelId: focusChannel ? _focusChannelId : _examChannelId,
          channelName: focusChannel ? _focusChannelName : _examChannelName,
          focusPopup: focusChannel,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
      debugPrint('[NotificationService] scheduleOneTime SUCCESS: id=$id');
    } catch (e) {
      debugPrint('[NotificationService] scheduleOneTime ERROR: $e');
    }
    debugPrint('[NotificationService] scheduleOneTime EXIT');
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
