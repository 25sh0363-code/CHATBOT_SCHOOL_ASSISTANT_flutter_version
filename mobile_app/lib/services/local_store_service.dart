import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/test_record.dart';
import '../models/timetable_entry.dart';
import '../models/worksheet_record.dart';

class LocalStoreService {
  static const String _testsKey = 'tests_v1';
  static const String _timetableKey = 'timetable_v1';
  static const String _worksheetsKey = 'worksheets_v1';
  static const String _darkModeKey = 'dark_mode_v1';

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
}
