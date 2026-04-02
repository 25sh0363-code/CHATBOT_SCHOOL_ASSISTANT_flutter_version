import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shared_test_result.dart';

class LeaderboardApiService {
  LeaderboardApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<void> submitResult(SharedTestResult result) async {
    final uri = Uri.parse(baseUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'submit_result',
        'id': result.id,
        'student_name': result.studentName,
        'subject': result.subject,
        'percentage': result.percentage,
        'test_title': result.testTitle,
        'created_at': result.createdAt.toIso8601String(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Submit failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteResult(String resultId) async {
    final uri = Uri.parse(baseUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'delete_result',
        'id': resultId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Delete failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<SharedTestResult>> fetchRecentResults({int limit = 100}) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': 'recent_results',
        'limit': '$limit',
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Recent fetch failed: ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    final list = _extractList(decoded, preferredKey: 'results');
    return list.map(_parseSharedResult).toList();
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String subject,
    int limit = 100,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': 'leaderboard',
        'subject': subject,
        'limit': '$limit',
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Leaderboard fetch failed: ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    final list = _extractList(decoded, preferredKey: 'leaderboard');
    return list.map(_parseLeaderboardEntry).toList();
  }

  List<Map<String, dynamic>> _extractList(dynamic decoded,
      {required String preferredKey}) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    if (decoded is Map<String, dynamic>) {
      final payload =
          decoded[preferredKey] ?? decoded['data'] ?? decoded['rows'];
      if (payload is List) {
        return payload.whereType<Map<String, dynamic>>().toList();
      }
    }

    throw Exception('Unexpected response shape for $preferredKey');
  }

  SharedTestResult _parseSharedResult(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['result_id'] ?? '').toString();
    final name = (json['student_name'] ?? json['studentName'] ?? '').toString();
    final subject = (json['subject'] ?? '').toString();
    final percentageRaw = json['percentage'] ?? json['avg_percentage'] ?? 0;
    final title = json['test_title'] ?? json['testTitle'];
    final createdRaw = json['created_at'] ?? json['createdAt'];

    return SharedTestResult(
      id: id.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : id,
      studentName: name,
      subject: subject,
      percentage: (percentageRaw as num).toDouble(),
      createdAt: DateTime.tryParse((createdRaw ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      testTitle: title == null ? null : title.toString(),
    );
  }

  LeaderboardEntry _parseLeaderboardEntry(Map<String, dynamic> json) {
    final attemptsRaw = json['attempts'] ?? json['count'] ?? 1;
    final averageRaw = json['average_percentage'] ??
        json['avg_percentage'] ??
        json['percentage'];
    final updatedRaw = json['updated_at'] ?? json['last_updated'];

    return LeaderboardEntry(
      studentName:
          (json['student_name'] ?? json['studentName'] ?? 'Unknown').toString(),
      subject: (json['subject'] ?? '').toString(),
      attempts: (attemptsRaw as num).toInt(),
      averagePercentage: (averageRaw as num).toDouble(),
      updatedAt: DateTime.tryParse((updatedRaw ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.studentName,
    required this.subject,
    required this.attempts,
    required this.averagePercentage,
    required this.updatedAt,
  });

  final String studentName;
  final String subject;
  final int attempts;
  final double averagePercentage;
  final DateTime updatedAt;
}
