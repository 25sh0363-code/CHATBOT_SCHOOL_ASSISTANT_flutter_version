import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/collab_user.dart';
import '../models/exam_event.dart';
import '../models/homework_task.dart';
import '../models/quick_note.dart';
import '../models/test_record.dart';
import '../models/timetable_entry.dart';
import '../models/todo_item.dart';
import '../models/worksheet_record.dart';

class LocalStoreService {
  static const String _testsKey = 'tests_v1';
  static const String _timetableKey = 'timetable_v1';
  static const String _worksheetsKey = 'worksheets_v1';
  static const String _darkModeKey = 'dark_mode_v1';
  static const String _chatHistoryKey = 'chat_history_v1';
  static const String _quickNotesKey = 'quick_notes_v1';
  static const String _homeworkTasksKey = 'homework_tasks_v1';
  static const String _todoItemsKey = 'todo_items_v1';
  static const String _examEventsKey = 'exam_events_v1';
  static const String _collabUserKey = 'collab_user_v1';
  static const String _focusTimerEndsAtKey = 'focus_timer_ends_at_v1';

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

  Future<List<TimetableEntry>> loadTimetableEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timetableKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TimetableEntry.fromJson)
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> saveTimetableEntries(List<TimetableEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_timetableKey, payload);
  }

  Future<List<WorksheetRecord>> loadWorksheets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_worksheetsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WorksheetRecord.fromJson)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveWorksheets(List<WorksheetRecord> worksheets) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(worksheets.map((e) => e.toJson()).toList());
    await prefs.setString(_worksheetsKey, payload);
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

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(QuickNote.fromJson)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> saveQuickNotes(List<QuickNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(notes.map((e) => e.toJson()).toList());
    await prefs.setString(_quickNotesKey, payload);
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

  Future<List<TodoItem>> loadTodoItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_todoItemsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TodoItem.fromJson)
        .toList();

    list.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (!a.isCompleted) {
        return a.dueDate.compareTo(b.dueDate);
      }
      final aCompleted = a.completedAt ?? a.createdAt;
      final bCompleted = b.completedAt ?? b.createdAt;
      return bCompleted.compareTo(aCompleted);
    });

    return list;
  }

  Future<void> saveTodoItems(List<TodoItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_todoItemsKey, payload);
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
}
