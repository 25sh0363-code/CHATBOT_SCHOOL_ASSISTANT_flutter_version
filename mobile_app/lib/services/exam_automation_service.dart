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
      await _storeService.saveExamEvents(cleaned);
    }

    await syncReminders(cleaned);
    return cleaned;
  }

  Future<void> saveAndSync(List<ExamEvent> exams) async {
    final cleaned = _removeCompletedExams(exams);
    await _storeService.saveExamEvents(cleaned);
    await syncReminders(cleaned);
  }

  Future<void> syncReminders(List<ExamEvent> exams) async {
    for (final exam in exams) {
      final id = _reminderId(exam.id);
      await NotificationService.instance.cancel(id);

      final now = DateTime.now();
      final examDateOnly = DateTime(
        exam.examDate.year,
        exam.examDate.month,
        exam.examDate.day,
      );
      final today = DateTime(now.year, now.month, now.day);

      if (examDateOnly.isBefore(today)) {
        continue;
      }

      await NotificationService.instance.scheduleDailyExamReminder(
        id: id,
        title: 'Exam Reminder: ${exam.title}',
        body:
            'Important exam coming up on ${_formatDate(exam.examDate)}. Revise today.',
        hour: _dailyReminderHour,
        minute: _dailyReminderMinute,
      );
    }
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

  int _reminderId(String examId) {
    return NotificationService.stableIdFromText(examId, offset: 100000);
  }

  static String _formatDate(DateTime value) {
    final year = value.year;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
