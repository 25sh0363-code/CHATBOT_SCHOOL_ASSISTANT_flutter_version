import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/collab_user.dart';
import '../models/exam_event.dart';
import '../models/homework_task.dart';
import '../models/mind_map_record.dart';
import '../models/quick_note.dart';
import '../models/shared_test_result.dart';
import '../models/test_record.dart';
import '../models/worksheet_record.dart';

class LocalStoreService {
  static const String _dailyReminderHourKey = 'daily_reminder_hour_v1';
  static const String _dailyReminderMinuteKey = 'daily_reminder_minute_v1';
  Future<int> loadDailyReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyReminderHourKey) ?? 7;
  }

  Future<int> loadDailyReminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyReminderMinuteKey) ?? 0;
  }

  Future<void> saveDailyReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyReminderHourKey, hour);
    await prefs.setInt(_dailyReminderMinuteKey, minute);
  }

  static const String _testsKey = 'tests_v1';
  static const String _worksheetsKey = 'worksheets_v1';
  static const String _mindMapsKey = 'mind_maps_v1';
  static const String _darkModeKey = 'dark_mode_v1';
  static const String _chatHistoryKey = 'chat_history_v1';
  static const String _quickNotesKey = 'quick_notes_v1';
  static const String _homeworkTasksKey = 'homework_tasks_v1';
  static const String _examEventsKey = 'exam_events_v1';
  static const String _collabUserKey = 'collab_user_v1';
  static const String _focusTimerEndsAtKey = 'focus_timer_ends_at_v1';
  static const String _learningJourneyKey = 'learning_journey_v1';
  static const String _sharedTestResultsKey = 'shared_test_results_v1';

  Future<List<TestRecord>> loadTests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_testsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TestRecord.fromJson)
        .toList();
    list.sort((a, b) => a.testDate.compareTo(b.testDate));
    return list;
  }

  Future<void> saveTests(List<TestRecord> tests) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(tests.map((e) => e.toJson()).toList());
    await prefs.setString(_testsKey, payload);
  }

  Future<List<WorksheetRecord>> loadWorksheets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_worksheetsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = <WorksheetRecord>[];
    for (final item in (jsonDecode(raw) as List<dynamic>)) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        list.add(WorksheetRecord.fromJson(item));
      } catch (_) {
        // Skip malformed older entries instead of failing the whole save/load flow.
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveWorksheets(List<WorksheetRecord> worksheets) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(worksheets.map((e) => e.toJson()).toList());
    await prefs.setString(_worksheetsKey, payload);
  }

  Future<List<MindMapRecord>> loadMindMaps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mindMapsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = <MindMapRecord>[];
    for (final item in (jsonDecode(raw) as List<dynamic>)) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        list.add(MindMapRecord.fromJson(item));
      } catch (_) {
        // Skip malformed older entries instead of failing the whole save/load flow.
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> saveMindMaps(List<MindMapRecord> mindMaps) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(mindMaps.map((e) => e.toJson()).toList());
    await prefs.setString(_mindMapsKey, payload);
  }

  Future<bool> loadDarkModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> saveDarkModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatHistoryKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    return list;
  }

  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(messages.map((e) => e.toJson()).toList());
    await prefs.setString(_chatHistoryKey, payload);
  }

  Future<void> clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);
  }

  Future<List<QuickNote>> loadQuickNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quickNotesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = <QuickNote>[];
    for (final item in (jsonDecode(raw) as List<dynamic>)) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        list.add(QuickNote.fromJson(item));
      } catch (_) {
        // Skip malformed older entries instead of failing the whole save/load flow.
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> saveQuickNotes(List<QuickNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(notes.map((e) => e.toJson()).toList());
    final ok = await prefs.setString(_quickNotesKey, payload);
    if (!ok) {
      throw Exception('Could not persist quick notes to local storage.');
    }
  }

  Future<List<HomeworkTask>> loadHomeworkTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homeworkTasksKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(HomeworkTask.fromJson)
        .toList();
    list.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.reminderTime.compareTo(b.reminderTime);
    });
    return list;
  }

  Future<void> saveHomeworkTasks(List<HomeworkTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_homeworkTasksKey, payload);
  }

  Future<List<ExamEvent>> loadExamEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_examEventsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ExamEvent.fromJson)
        .toList();
    list.sort((a, b) => a.examDate.compareTo(b.examDate));
    return list;
  }

  Future<void> saveExamEvents(List<ExamEvent> exams) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(exams.map((e) => e.toJson()).toList());
    await prefs.setString(_examEventsKey, payload);
  }

  Future<CollabUser?> loadCollabUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_collabUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return CollabUser.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> saveCollabUser(CollabUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collabUserKey, jsonEncode(user.toJson()));
  }

  Future<void> clearCollabUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collabUserKey);
  }

  Future<DateTime?> loadFocusTimerEndsAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_focusTimerEndsAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  Future<void> saveFocusTimerEndsAt(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_focusTimerEndsAtKey);
      return;
    }
    await prefs.setString(_focusTimerEndsAtKey, value.toIso8601String());
  }

  Future<Map<String, dynamic>?> loadLearningJourneyState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learningJourneyKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Future<void> saveLearningJourneyState(Map<String, dynamic>? state) async {
    final prefs = await SharedPreferences.getInstance();
    if (state == null) {
      await prefs.remove(_learningJourneyKey);
      return;
    }
    await prefs.setString(_learningJourneyKey, jsonEncode(state));
  }

  Future<List<SharedTestResult>> loadSharedTestResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sharedTestResultsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SharedTestResult.fromJson)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveSharedTestResults(List<SharedTestResult> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_sharedTestResultsKey, payload);
  }
}
