import '../models/exam_event.dart';
import 'local_store_service.dart';
import 'notification_service.dart';

class ExamAutomationService {
  ExamAutomationService({required LocalStoreService storeService})
      : _storeService = storeService;

  final LocalStoreService _storeService;

  static const int _dailyReminderHour = 7;
  static const int _dailyReminderMinute = 0;

  Future<List<ExamEvent>> loadCleanedAndSynced() async {
    final exams = await _storeService.loadExamEvents();
    final cleaned = _removeCompletedExams(exams);

    if (cleaned.length != exams.length) {
      // Cancel notifications for exams that have now passed.
      await _cancelAllDailyReminders();
      await _cancelAllCountdownReminders();
      await _storeService.saveExamEvents(cleaned);
    }

    // Sync notifications in background — don't block the screen load.
    syncReminders(cleaned).ignore();
    return cleaned;
  }

  Future<void> saveAndSync(List<ExamEvent> exams) async {
    final cleaned = _removeCompletedExams(exams);
    await _storeService.saveExamEvents(cleaned);
    // Cancel all existing reminders before rescheduling
    await _cancelAllDailyReminders();
    await _cancelAllCountdownReminders();
    // Fire reminder sync in background — don't block the calling UI.
    syncReminders(cleaned).ignore();
  }

  Future<void> syncReminders(List<ExamEvent> exams) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Cancel all existing daily reminders
    await _cancelAllDailyReminders();
    // Cancel all existing countdown reminders
    await _cancelAllCountdownReminders();

    if (exams.isEmpty) return;

    // Schedule daily reminders for ALL upcoming exams
    for (final exam in exams) {
      final examDate = DateTime(
        exam.examDate.year,
        exam.examDate.month,
        exam.examDate.day,
      );
      final daysLeft = examDate.difference(today).inDays;

      // Only schedule for future exams
      if (daysLeft >= 0) {
        await _scheduleDailyRemindersForExam(exam, daysLeft);

        // Schedule countdown notifications for exams today or tomorrow
        if (daysLeft <= 1) {
          await _scheduleCountdownReminders(exam);
        }
      }
    }
  }

  Future<void> _scheduleDailyRemindersForExam(ExamEvent exam, int daysLeft) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Schedule daily reminders from tomorrow until exam day
    for (int dayOffset = 1; dayOffset <= daysLeft; dayOffset++) {
      final reminderDate = today.add(Duration(days: dayOffset));
      final notifyAt = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        _dailyReminderHour,
        _dailyReminderMinute,
      );

      // Skip if this reminder time has already passed today
      if (dayOffset == 1 && now.isAfter(notifyAt)) {
        continue;
      }

      String body;
      final title = 'Exam Reminder: ${exam.title}';

      if (dayOffset == daysLeft) {
        // Last reminder before exam
        body = 'Tomorrow is your ${exam.title} exam — final revision time!';
      } else {
        // Regular reminder
        final daysUntil = daysLeft - dayOffset + 1;
        body = '${daysUntil - 1} days until your ${exam.title} (${exam.subject}) exam. Keep revising!';
      }

      try {
        await NotificationService.instance.scheduleOneTime(
          id: _dailyReminderId(exam.id, dayOffset),
          title: title,
          body: body,
          at: notifyAt,
        );
      } catch (_) {}
    }

    // Special case: if exam is today and it's before 7 AM, schedule for today
    if (daysLeft == 0) {
      final today7am = DateTime(
        today.year,
        today.month,
        today.day,
        _dailyReminderHour,
        _dailyReminderMinute,
      );
      if (now.isBefore(today7am)) {
        final title = 'Exam Reminder: ${exam.title}';
        final body = 'Today is the day! Good luck on your ${exam.title} exam!';
        try {
          await NotificationService.instance.scheduleOneTime(
            id: _dailyReminderId(exam.id, 0),
            title: title,
            body: body,
            at: today7am,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _scheduleCountdownReminders(ExamEvent exam) async {
    final now = DateTime.now();
    final examDateTime = DateTime(
      exam.examDate.year,
      exam.examDate.month,
      exam.examDate.day,
    );

    // Define countdown intervals (in minutes before exam)
    final intervals = [60, 30, 15, 5, 0]; // 0 means at exam time

    for (final minutesBefore in intervals) {
      final notifyAt = examDateTime.subtract(Duration(minutes: minutesBefore));

      // Only schedule if the time is in the future
      if (notifyAt.isAfter(now)) {
        String body;
        if (minutesBefore == 0) {
          body = 'Your ${exam.title} exam starts now! Good luck!';
        } else {
          body = '${exam.title} exam in $minutesBefore minutes. Get ready!';
        }

        final title = 'Exam Countdown: ${exam.title}';

        try {
          await NotificationService.instance.scheduleOneTime(
            id: _countdownReminderId(exam.id, minutesBefore),
            title: title,
            body: body,
            at: notifyAt,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _cancelAllCountdownReminders() async {
    // Cancel all possible countdown reminder IDs
    for (var examIndex = 0; examIndex < 1000; examIndex++) {
      for (final minutes in [60, 30, 15, 5, 0]) {
        try {
          await NotificationService.instance.cancel(900000 + examIndex * 10 + minutes ~/ 10);
        } catch (_) {}
      }
    }
  }

  int _countdownReminderId(String examId, int minutesBefore) {
    var hash = 0;
    for (final rune in examId.runes) {
      hash = (hash * 31 + rune) & 0x7FFFFFFF;
    }
    return 900000 + (hash % 1000) * 10 + minutesBefore ~/ 10;
  }

  List<ExamEvent> _removeCompletedExams(List<ExamEvent> exams) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return exams.where((exam) {
      final date =
          DateTime(exam.examDate.year, exam.examDate.month, exam.examDate.day);
      return !date.isBefore(today);
    }).toList();
  }

  Future<void> _cancelAllDailyReminders() async {
    // Cancel all possible daily reminder IDs (now supporting multiple days per exam)
    // Range: 800000 to 899999 (100,000 IDs total, supporting ~10 exams with ~10 days each)
    for (var i = 0; i < 100000; i++) {
      try {
        await NotificationService.instance.cancel(800000 + i);
      } catch (_) {}
    }
  }

  int _dailyReminderId(String examId, int dayOffset) {
    var hash = 0;
    for (final rune in examId.runes) {
      hash = (hash * 31 + rune) & 0x7FFFFFFF;
    }
    // Use different ranges for different day offsets to avoid conflicts
    return 800000 + (hash % 1000) + (dayOffset * 10000);
  }

  // TEMPORARY TEST METHOD - Remove after testing
  Future<void> scheduleTestNotification() async {
    // ignore: avoid_print
    print('[ExamAutomationService] scheduleTestNotification ENTRY');
    final now = DateTime.now();
    final testTime = now.add(const Duration(seconds: 15)); // 15 seconds from now

    try {
      // ignore: avoid_print
      print('[ExamAutomationService] Scheduling one-time notification for $testTime');
      await NotificationService.instance.scheduleOneTime(
        id: 999999, // Unique test ID
        title: '🧪 Test Notification',
        body:
            'Test notification scheduled for ${testTime.toLocal()}. Close the app and watch for it.',
        at: testTime,
      );
      // ignore: avoid_print
      print('[ExamAutomationService] Scheduling immediate notification');
      await NotificationService.instance.showNow(
        id: 999998,
        title: '🧪 Test Notification (Immediate)',
        body:
            'If you see this, notifications are working. The scheduled one should follow in 15 seconds.',
      );
      // ignore: avoid_print
      print('[ExamAutomationService] scheduleTestNotification SUCCESS');
    } catch (e) {
      // ignore: avoid_print
      print('[ExamAutomationService] scheduleTestNotification ERROR: $e');
      // Test notification failed - error will be shown in UI
    }
    // ignore: avoid_print
    print('[ExamAutomationService] scheduleTestNotification EXIT');
  }
}
