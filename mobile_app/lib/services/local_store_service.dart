import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/collab_user.dart';
import '../models/exam_event.dart';
import '../models/homework_task.dart';
import '../models/learning_journey_record.dart';
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
  static const String _chatSessionsKey = 'chat_sessions_v1';
  static const String _quickNotesKey = 'quick_notes_v1';
  static const String _homeworkTasksKey = 'homework_tasks_v1';
  static const String _examEventsKey = 'exam_events_v1';
  static const String _collabUserKey = 'collab_user_v1';
  static const String _focusTimerEndsAtKey = 'focus_timer_ends_at_v1';
  static const String _learningJourneysKey = 'learning_journeys_v1';
  static const String _learningJourneyKey = 'learning_journey_v1';
  static const String _sharedTestResultsKey = 'shared_test_results_v1';
  static const String _profileNameKey = 'profile_name_v1';
  static const String _profilePhotoBase64Key = 'profile_photo_base64_v1';
  static const String _dailyQuoteEnabledKey = 'daily_quote_enabled_v1';
  static const String _hapticsEnabledKey = 'haptics_enabled_v1';

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

  Future<Map<String, dynamic>?> loadChatSessionsPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatSessionsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Future<void> saveChatSessionsPayload(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatSessionsKey, jsonEncode(payload));
  }

  Future<void> clearChatSessionsPayload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatSessionsKey);
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

  Future<List<LearningJourneyRecord>> loadLearningJourneys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learningJourneysKey);
    if (raw == null || raw.isEmpty) {
      final legacyRaw = prefs.getString(_learningJourneyKey);
      if (legacyRaw == null || legacyRaw.isEmpty) {
        return [];
      }

      final decodedLegacy = jsonDecode(legacyRaw);
      if (decodedLegacy is! Map<String, dynamic>) {
        return [];
      }

      final now = DateTime.now();
      final record = LearningJourneyRecord(
        id: 'legacy_learning_journey',
        title: (decodedLegacy['examName'] ?? 'Learning Journey')
                .toString()
                .trim()
                .isEmpty
            ? 'Learning Journey'
            : decodedLegacy['examName'].toString(),
        examName: decodedLegacy['examName']?.toString() ?? '',
        subject: decodedLegacy['subject']?.toString() ?? 'physics',
        state: decodedLegacy,
        createdAt: now,
        updatedAt: now,
      );
      await saveLearningJourneyRecord(record);
      return [record];
    }

    final list = <LearningJourneyRecord>[];
    for (final item in (jsonDecode(raw) as List<dynamic>)) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        list.add(LearningJourneyRecord.fromJson(item));
      } catch (_) {
        // Skip malformed entries.
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<LearningJourneyRecord?> loadLearningJourneyRecord(String id) async {
    final journeys = await loadLearningJourneys();
    for (final record in journeys) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  Future<LearningJourneyRecord?> loadLatestLearningJourney() async {
    final journeys = await loadLearningJourneys();
    if (journeys.isEmpty) {
      return null;
    }
    return journeys.first;
  }

  Future<void> saveLearningJourneys(
      List<LearningJourneyRecord> journeys) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(journeys.map((e) => e.toJson()).toList());
    await prefs.setString(_learningJourneysKey, payload);
  }

  Future<void> saveLearningJourneyRecord(LearningJourneyRecord record) async {
    final journeys = await loadLearningJourneys();
    final index = journeys.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      journeys[index] = record;
    } else {
      journeys.insert(0, record);
    }
    journeys.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await saveLearningJourneys(journeys);
  }

  Future<void> deleteLearningJourney(String id) async {
    final journeys = await loadLearningJourneys();
    journeys.removeWhere((item) => item.id == id);
    await saveLearningJourneys(journeys);
  }

  Future<Map<String, dynamic>?> loadLearningJourneyState() async {
    final latest = await loadLatestLearningJourney();
    return latest?.state;
  }

  Future<void> saveLearningJourneyState(Map<String, dynamic>? state) async {
    if (state == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_learningJourneyKey);
      return;
    }

    final now = DateTime.now();
    final latest = await loadLatestLearningJourney();
    final id = (state['id']?.toString().trim().isNotEmpty ?? false)
        ? state['id'].toString()
        : (latest?.id ?? 'learning_journey_${now.microsecondsSinceEpoch}');
    final record = LearningJourneyRecord(
      id: id,
      title: (state['title']?.toString().trim().isNotEmpty ?? false)
          ? state['title'].toString()
          : (state['examName']?.toString().trim().isNotEmpty ?? false)
              ? state['examName'].toString()
              : 'Learning Journey',
      examName: state['examName']?.toString() ?? '',
      subject: state['subject']?.toString() ?? 'physics',
      state: state,
      createdAt: now,
      updatedAt: now,
    );
    await saveLearningJourneyRecord(record);
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

  Future<String> loadProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_profileNameKey)?.trim() ?? '';
    return value.isEmpty ? 'Student' : value;
  }

  Future<void> saveProfileName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileNameKey, name.trim());
  }

  Future<String?> loadProfilePhotoBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_profilePhotoBase64Key)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> saveProfilePhotoBase64(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_profilePhotoBase64Key);
      return;
    }
    await prefs.setString(_profilePhotoBase64Key, value.trim());
  }

  Future<bool> loadDailyQuoteEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dailyQuoteEnabledKey) ?? true;
  }

  Future<void> saveDailyQuoteEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyQuoteEnabledKey, enabled);
  }

  Future<bool> loadHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticsEnabledKey) ?? true;
  }

  Future<void> saveHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsEnabledKey, enabled);
  }
}
