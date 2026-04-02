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

    final decoded = _tryDecodeMap(response.body);
    if (decoded != null && decoded['ok'] == false) {
      throw Exception('Submit failed: ${decoded['error'] ?? _preview(response.body)}');
    }
  }

  Future<void> deleteResult(SharedTestResult result) async {
    final uri = Uri.parse(baseUrl);
    final payload = <String, dynamic>{
      'action': 'delete_result',
      'id': result.id,
      'result_id': result.id,
      'student_name': result.studentName,
      'subject': result.subject,
      'percentage': result.percentage,
      'test_title': result.testTitle,
      'created_at': result.createdAt.toIso8601String(),
    };

    final postResponse = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (postResponse.statusCode >= 200 && postResponse.statusCode < 300) {
      final decoded = _tryDecodeMap(postResponse.body);
      final isSuccess = decoded == null ||
          decoded['ok'] == true ||
          decoded['deleted'] == true ||
          decoded['status'] == 'ok';
      if (isSuccess) {
        return;
      }
    }

    // Some Apps Script deployments only support doGet for delete_result.
    final getUri = uri.replace(
      queryParameters: {
        'action': 'delete_result',
        'id': result.id,
        'result_id': result.id,
        'student_name': result.studentName,
        'subject': result.subject,
        'percentage': result.percentage.toString(),
        if (result.testTitle != null) 'test_title': result.testTitle!,
        'created_at': result.createdAt.toIso8601String(),
      },
    );
    final getResponse = await _client.get(getUri);
    if (getResponse.statusCode < 200 || getResponse.statusCode >= 300) {
      throw Exception(
        'Delete failed: ${postResponse.statusCode}/${getResponse.statusCode} '
        '${_preview(getResponse.body)}',
      );
    }

    final decoded = _tryDecodeMap(getResponse.body);
    final isSuccess = decoded == null ||
        decoded['ok'] == true ||
        decoded['deleted'] == true ||
        decoded['status'] == 'ok';
    if (!isSuccess) {
      throw Exception('Delete failed: ${decoded['error'] ?? _preview(getResponse.body)}');
    }
  }

  Future<List<SharedTestResult>> fetchRecentResults({int limit = 100}) async {
    final dynamic decoded = await _readAction(
      action: 'recent_results',
      params: {'limit': '$limit'},
    );
    final list = _extractList(decoded, preferredKey: 'results');
    return list.map(_parseSharedResult).toList();
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String subject,
    int limit = 100,
  }) async {
    final dynamic decoded = await _readAction(
      action: 'leaderboard',
      params: {
        'subject': subject,
        'limit': '$limit',
      },
    );
    final list = _extractList(decoded, preferredKey: 'leaderboard');
    return list.map(_parseLeaderboardEntry).toList();
  }

  Future<dynamic> _readAction({
    required String action,
    Map<String, String> params = const <String, String>{},
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': action,
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
        ...params,
      },
    );

    final getResponse = await _client.get(uri);
    if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
      try {
        return jsonDecode(getResponse.body);
      } catch (_) {
        // Fall back to POST when Apps Script is deployed with doPost only.
      }
    }

    final postResponse = await _client.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': action,
        ...params,
      }),
    );
    if (postResponse.statusCode < 200 || postResponse.statusCode >= 300) {
      throw Exception(
        '$action failed: ${postResponse.statusCode} ${_preview(postResponse.body)}',
      );
    }
    try {
      return jsonDecode(postResponse.body);
    } catch (_) {
      throw Exception(
        '$action returned non-JSON response: ${_preview(postResponse.body)}',
      );
    }
  }

  String _preview(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 160) {
      return compact;
    }
    return '${compact.substring(0, 160)}...';
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Keep null to indicate non-JSON responses.
    }
    return null;
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
    final percentageValue = percentageRaw is num
      ? percentageRaw.toDouble()
      : double.tryParse(percentageRaw.toString()) ?? 0;
    final title = json['test_title'] ?? json['testTitle'];
    final createdRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = DateTime.tryParse((createdRaw ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final fallbackId = _stableResultKey(
      studentName: name,
      subject: subject,
      percentage: percentageValue,
      createdAt: createdAt,
      testTitle: title?.toString(),
    );

    return SharedTestResult(
      id: id.isEmpty ? fallbackId : id,
      studentName: name,
      subject: subject,
      percentage: percentageValue,
      createdAt: createdAt,
      testTitle: title == null ? null : title.toString(),
    );
  }

  String buildResultSyncKey(SharedTestResult result) {
    return _stableResultKey(
      studentName: result.studentName,
      subject: result.subject,
      percentage: result.percentage,
      createdAt: result.createdAt,
      testTitle: result.testTitle,
    );
  }

  String _stableResultKey({
    required String studentName,
    required String subject,
    required double percentage,
    required DateTime createdAt,
    required String? testTitle,
  }) {
    final normalizedName = studentName.trim().toLowerCase();
    final normalizedSubject = subject.trim().toLowerCase();
    final normalizedTitle = (testTitle ?? '').trim().toLowerCase();
    return [
      normalizedName,
      normalizedSubject,
      percentage.toStringAsFixed(4),
      createdAt.toUtc().toIso8601String(),
      normalizedTitle,
    ].join('|');
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
