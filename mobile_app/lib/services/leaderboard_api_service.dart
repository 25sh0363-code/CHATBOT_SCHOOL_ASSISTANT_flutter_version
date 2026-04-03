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

    // Apps Script /exec redirects POST, so use GET directly for submit
    final getUri = uri.replace(
      queryParameters: {
        'action': 'submit_result',
        'id': result.id,
        'student_name': result.studentName,
        'subject': result.subject,
        'percentage': result.percentage.toString(),
        if (result.testTitle != null) 'test_title': result.testTitle!,
        'created_at': result.createdAt.toIso8601String(),
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final getResponse = await _getWithAppsScriptRedirect(getUri);
    if (getResponse.statusCode < 200 || getResponse.statusCode >= 300) {
      throw Exception('Submit failed: ${getResponse.statusCode} ${_preview(getResponse.body)}');
    }

    final decoded = _tryDecodeMap(getResponse.body);
    final isSuccess = decoded == null ||
        decoded['ok'] == true ||
        decoded['status'] == 'ok';
    if (!isSuccess) {
      throw Exception('Submit failed: ${decoded['error'] ?? _preview(getResponse.body)}');
    }
  }

  Future<void> deleteResult(SharedTestResult result) async {
    final uri = Uri.parse(baseUrl);

    // Use GET directly for delete (Apps Script /exec redirects POST)
    final getUri = uri.replace(
      queryParameters: {
        'action': 'delete_result',
        'id': result.id,
        'result_id': result.id,
        'student_name': result.studentName,
        'subject': result.subject,
        'percentage': result.percentage.toString(),
        if (result.testTitle != null) 'test_title': result.testTitle!,
        'created_at': result.createdAt.toUtc().toIso8601String(),
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final getResponse = await _getWithAppsScriptRedirect(getUri);
    if (getResponse.statusCode < 200 || getResponse.statusCode >= 300) {
      throw Exception('Delete failed: ${getResponse.statusCode} ${_preview(getResponse.body)}');
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

    final getResponse = await _getWithAppsScriptRedirect(uri);
    if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
      try {
        return jsonDecode(getResponse.body);
      } catch (_) {
        final bodyPreview = _preview(getResponse.body);
        if (bodyPreview.startsWith('<!DOCTYPE html>') ||
            bodyPreview.startsWith('<html') ||
            bodyPreview.contains('script.google.com')) {
          throw Exception(
            'Apps Script deployment returned HTML instead of JSON for $action. '
            'Open the deployed /exec web app URL and make sure doGet/doPost are published.',
          );
        }
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
      final bodyPreview = _preview(postResponse.body);
      if (bodyPreview.startsWith('<!DOCTYPE html>') ||
          bodyPreview.startsWith('<html') ||
          bodyPreview.contains('script.google.com')) {
        throw Exception(
          'Apps Script deployment returned HTML instead of JSON for $action. '
          'The leaderboard web app likely needs redeployment or a corrected /exec URL.',
        );
      }
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

  Future<http.Response> _getWithAppsScriptRedirect(Uri uri) async {
    final response = await _client.get(uri);

    // Some Apps Script deployments respond with an HTML "Moved Temporarily"
    // page that contains a script.googleusercontent.com redirect URL.
    final redirectFromHtml = _extractHtmlRedirect(response.body);
    if (redirectFromHtml != null) {
      final redirected = await _client.get(redirectFromHtml);
      return redirected;
    }

    // If HTTP redirect is exposed without auto-follow, follow one hop.
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location != null && location.trim().isNotEmpty) {
        final redirected = await _client.get(Uri.parse(location));
        return redirected;
      }
    }

    return response;
  }

  Uri? _extractHtmlRedirect(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!compact.toLowerCase().contains('moved temporarily')) {
      return null;
    }

    final href = RegExp(r'href="([^"]+)"', caseSensitive: false)
        .firstMatch(body)
        ?.group(1);
    if (href == null || href.isEmpty) {
      return null;
    }
    return Uri.tryParse(href);
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
      testTitle: title?.toString(),
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
    // Normalize datetime to UTC without milliseconds
    final createdUtcTruncated = DateTime.utc(
      createdAt.year,
      createdAt.month,
      createdAt.day,
      createdAt.hour,
      createdAt.minute,
      createdAt.second,
    );
    return [
      normalizedName,
      normalizedSubject,
      percentage.toStringAsFixed(1),
      createdUtcTruncated.toIso8601String(),
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
