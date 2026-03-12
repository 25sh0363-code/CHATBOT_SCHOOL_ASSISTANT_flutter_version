import '../models/exam_event.dart';
import 'local_store_service.dart';
import 'notification_service.dart';

class ExamAutomationService {
  ExamAutomationService({required LocalStoreService storeService})
      : _storeService = storeService;

  final LocalStoreService _storeService;

  static const int _dailyReminderHour = 7;
  static const int _dailyReminderMinute = 0;
  // Max individual countdown notifications scheduled per exam.
  static const int _maxCountdownDays = 60;

  Future<List<ExamEvent>> loadCleanedAndSynced() async {
    final exams = await _storeService.loadExamEvents();
    final cleaned = _removeCompletedExams(exams);

    if (cleaned.length != exams.length) {
      // Cancel notifications for exams that have now passed.
      for (final exam in exams) {
        if (!cleaned.any((e) => e.id == exam.id)) {
          _cancelCountdown(exam.id).ignore();
        }
      }
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

    for (final exam in exams) {
      // Cancel all previously scheduled countdown slots for this exam.
      await _cancelCountdown(exam.id);

      final examDate = DateTime(
        exam.examDate.year,
        exam.examDate.month,
        exam.examDate.day,
      );
      final daysLeft = examDate.difference(today).inDays;
      if (daysLeft < 0) continue;

      // Schedule one notification per day from today until exam day (up to
      // _maxCountdownDays). Each message reflects how many days are left.
      for (var i = 0; i <= daysLeft.clamp(0, _maxCountdownDays - 1); i++) {
        final notifyAt = DateTime(
          today.year,
          today.month,
          today.day + i,
          _dailyReminderHour,
          _dailyReminderMinute,
        );
        if (notifyAt.isBefore(now)) continue;

        final daysRemaining = daysLeft - i;
        final body = daysRemaining == 0
            ? 'Today is the day! Good luck on your ${exam.title} exam!'
            : daysRemaining == 1
                ? 'Tomorrow is your ${exam.title} exam — final revision time!'
                : '$daysRemaining days until your ${exam.title}'
                    ' (${exam.subject}) exam. Keep revising!';

        try {
          await NotificationService.instance.scheduleOneTime(
            id: _countdownId(exam.id, i),
            title: 'Exam Countdown: ${exam.title}',
            body: body,
            at: notifyAt,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _cancelCountdown(String examId) async {
    for (var i = 0; i < _maxCountdownDays; i++) {
      try {
        await NotificationService.instance.cancel(_countdownId(examId, i));
      } catch (_) {}
    }
  }

  int _countdownId(String examId, int dayOffset) {
    var hash = 0;
    for (final rune in examId.runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    return 200000 + (hash % 10000) * _maxCountdownDays + dayOffset;
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
}
