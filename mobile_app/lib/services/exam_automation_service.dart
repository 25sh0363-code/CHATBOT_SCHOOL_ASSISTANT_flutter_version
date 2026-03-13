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
      await _storeService.saveExamEvents(cleaned);
    }

    // Sync notifications in background — don't block the screen load.
    syncReminders(cleaned).ignore();
    return cleaned;
  }

  Future<void> saveAndSync(List<ExamEvent> exams) async {
    final cleaned = _removeCompletedExams(exams);
    await _storeService.saveExamEvents(cleaned);
    // Fire reminder sync in background — don't block the calling UI.
    syncReminders(cleaned).ignore();
  }

  Future<void> syncReminders(List<ExamEvent> exams) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Cancel all existing daily reminders
    await _cancelAllDailyReminders();

    if (exams.isEmpty) return;

    // Find the next upcoming exam
    ExamEvent? nextExam;
    int minDaysLeft = double.maxFinite.toInt();

    for (final exam in exams) {
      final examDate = DateTime(
        exam.examDate.year,
        exam.examDate.month,
        exam.examDate.day,
      );
      final daysLeft = examDate.difference(today).inDays;
      if (daysLeft >= 0 && daysLeft < minDaysLeft) {
        minDaysLeft = daysLeft;
        nextExam = exam;
      }
    }

    if (nextExam == null) return;

    // Determine when to schedule the next notification
    DateTime notifyAt;
    String body;

    if (minDaysLeft == 0) {
      // Exam is today - schedule for 7am if it's before 7am, otherwise don't schedule
      final today7am = DateTime(
        today.year,
        today.month,
        today.day,
        _dailyReminderHour,
        _dailyReminderMinute,
      );
      if (now.isBefore(today7am)) {
        notifyAt = today7am;
        body = 'Today is the day! Good luck on your ${nextExam.title} exam!';
      } else {
        // Already past 7am, don't schedule notification for today
        return;
      }
    } else {
      // Schedule for tomorrow at 7am
      final tomorrow = today.add(const Duration(days: 1));
      notifyAt = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        _dailyReminderHour,
        _dailyReminderMinute,
      );

      body = minDaysLeft == 1
          ? 'Tomorrow is your ${nextExam.title} exam — final revision time!'
          : '${minDaysLeft - 1} days until your ${nextExam.title} (${nextExam.subject}) exam. Keep revising!';
    }

    final title = 'Exam Countdown: ${nextExam.title}';

    try {
      await NotificationService.instance.scheduleOneTime(
        id: _dailyReminderId(nextExam.id),
        title: title,
        body: body,
        at: notifyAt,
      );
    } catch (_) {}
  }

  Future<void> _cancelAllDailyReminders() async {
    // Cancel all possible daily reminder IDs (we'll use a simple ID scheme)
    for (var i = 0; i < 1000; i++) {
      try {
        await NotificationService.instance.cancel(800000 + i);
      } catch (_) {}
    }
  }

  int _dailyReminderId(String examId) {
    var hash = 0;
    for (final rune in examId.runes) {
      hash = (hash * 31 + rune) & 0x7FFFFFFF;
    }
    return 800000 + (hash % 1000);
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

  // TEMPORARY TEST METHOD - Remove after testing
  Future<void> scheduleTestNotification() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 2)); // 2 minutes from now

    try {
      await NotificationService.instance.scheduleOneTime(
        id: 999999, // Unique test ID
        title: '🧪 Test Notification',
        body: 'This is a test to verify notifications work when app is closed. If you see this, notifications are working!',
        at: testTime,
      );
      print('Test notification scheduled for ${testTime.toString()}');
    } catch (e) {
      print('Failed to schedule test notification: $e');
    }
  }
}
