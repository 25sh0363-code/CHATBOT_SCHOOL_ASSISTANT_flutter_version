import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/test_record.dart';

class LocalStoreService {
  static const String _testsKey = 'tests_v1';

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
}
