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

    // Prefer POST to avoid URL length limits when profile photo base64 is present.
    try {
      final postResponse = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'submit_result',
          'id': result.id,
          'student_name': result.studentName,
          'subject': result.subject,
          'score': result.score,
          'max_marks': result.maxMarks,
          'percentage': result.percentage,
          if (result.testTitle != null) 'test_title': result.testTitle,
          if (result.profilePhotoBase64 != null)
            'profile_photo_base64': result.profilePhotoBase64,
          'created_at': result.createdAt.toIso8601String(),
        }),
      );
      if (postResponse.statusCode >= 200 && postResponse.statusCode < 300) {
        final decoded = _tryDecodeMap(postResponse.body);
        final isSuccess = decoded == null ||
            decoded['ok'] == true ||
            decoded['status'] == 'ok';
        if (isSuccess) {
          return;
        }
      }
    } catch (_) {
      // Fall through to GET fallback for deployments that only accept GET.
    }

    final getUri = uri.replace(
      queryParameters: {
        'action': 'submit_result',
        'id': result.id,
        'student_name': result.studentName,
        'subject': result.subject,
        'score': result.score.toString(),
        'max_marks': result.maxMarks.toString(),
        'percentage': result.percentage.toString(),
        if (result.testTitle != null) 'test_title': result.testTitle!,
        // Do not send profile photo over GET query; payload can exceed URL limits.
        'created_at': result.createdAt.toIso8601String(),
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final getResponse = await _getWithAppsScriptRedirect(getUri);
    if (getResponse.statusCode < 200 || getResponse.statusCode >= 300) {
      throw Exception(
          'Submit failed: ${getResponse.statusCode} ${_preview(getResponse.body)}');
    }

    final decoded = _tryDecodeMap(getResponse.body);
    final isSuccess =
        decoded == null || decoded['ok'] == true || decoded['status'] == 'ok';
    if (!isSuccess) {
      throw Exception(
          'Submit failed: ${decoded['error'] ?? _preview(getResponse.body)}');
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
        'score': result.score.toString(),
        'max_marks': result.maxMarks.toString(),
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

  Future<LeaderboardSyncBundle> fetchSyncBundle({
    required String subject,
    int recentLimit = 50,
    int leaderboardLimit = 50,
  }) async {
    try {
      final dynamic decoded = await _readAction(
        action: 'sync_bundle',
        params: {
          'subject': subject,
          'recent_limit': '$recentLimit',
          'leaderboard_limit': '$leaderboardLimit',
        },
      );

      if (decoded is Map<String, dynamic>) {
        final recentList = _extractList(decoded, preferredKey: 'results');
        final leaderboardList =
            _extractList(decoded, preferredKey: 'leaderboard');
        return LeaderboardSyncBundle(
          recentResults: recentList.map(_parseSharedResult).toList(),
          leaderboard: leaderboardList.map(_parseLeaderboardEntry).toList(),
        );
      }
    } catch (_) {
      // Fallback below keeps compatibility with older backend deployments.
    }

    final payload = await Future.wait([
      fetchRecentResults(limit: recentLimit),
      fetchLeaderboard(subject: subject, limit: leaderboardLimit),
    ]);
    return LeaderboardSyncBundle(
      recentResults: payload[0] as List<SharedTestResult>,
      leaderboard: payload[1] as List<LeaderboardEntry>,
    );
  }

  Future<dynamic> _readAction({
    required String action,
    Map<String, String> params = const <String, String>{},
  }) async {
    final postResponse = await _client.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': action,
        ...params,
      }),
    );
    if (postResponse.statusCode >= 200 && postResponse.statusCode < 300) {
      try {
        return jsonDecode(postResponse.body);
      } catch (_) {}
    }

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
            'The leaderboard web app likely needs redeployment or a corrected /exec URL.',
          );
        }
      }
    }

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
    final scoreRaw = json['score'] ?? json['marks_obtained'];
    final maxMarksRaw = json['max_marks'] ?? json['maxMarks'];
    final percentageRaw = json['percentage'] ?? json['avg_percentage'] ?? 0;
    final scoreValue = scoreRaw is num
        ? scoreRaw.toDouble()
        : double.tryParse((scoreRaw ?? '').toString());
    final maxMarksValue = maxMarksRaw is num
        ? maxMarksRaw.toDouble()
        : double.tryParse((maxMarksRaw ?? '').toString());
    final percentageValue = percentageRaw is num
        ? percentageRaw.toDouble()
        : double.tryParse(percentageRaw.toString()) ?? 0;
    final resolvedScore = scoreValue ?? percentageValue;
    final resolvedMaxMarks =
      (maxMarksValue != null && maxMarksValue > 0) ? maxMarksValue : 100.0;
    final title = json['test_title'] ?? json['testTitle'];
    final createdRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = DateTime.tryParse((createdRaw ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final photoRaw =
        json['profile_photo_base64'] ?? json['profilePhotoBase64'] ?? json['avatar'];

    final fallbackId = _stableResultKey(
      studentName: name,
      subject: subject,
      score: resolvedScore,
      maxMarks: resolvedMaxMarks,
      createdAt: createdAt,
      testTitle: title?.toString(),
    );

    return SharedTestResult(
      id: id.isEmpty ? fallbackId : id,
      studentName: name,
      subject: subject,
      score: resolvedScore,
      maxMarks: resolvedMaxMarks,
      createdAt: createdAt,
      testTitle: title?.toString(),
      profilePhotoBase64:
          photoRaw == null ? null : photoRaw.toString().trim().isEmpty ? null : photoRaw.toString(),
    );
  }

  String buildResultSyncKey(SharedTestResult result) {
    return _stableResultKey(
      studentName: result.studentName,
      subject: result.subject,
      score: result.score,
      maxMarks: result.maxMarks,
      createdAt: result.createdAt,
      testTitle: result.testTitle,
    );
  }

  String _stableResultKey({
    required String studentName,
    required String subject,
    required double score,
    required double maxMarks,
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
      score.toStringAsFixed(2),
      maxMarks.toStringAsFixed(2),
      createdUtcTruncated.toIso8601String(),
      normalizedTitle,
    ].join('|');
  }

  LeaderboardEntry _parseLeaderboardEntry(Map<String, dynamic> json) {
    final attemptsRaw = json['attempts'] ?? json['count'] ?? 1;
    final averageRaw = json['average_percentage'] ??
        json['avg_percentage'] ??
        json['percentage'];
    final averageScoreRaw = json['average_score'] ??
      json['avg_score'] ??
      json['score'] ??
      json['marks_obtained'];
    final averageMaxMarksRaw =
      json['average_max_marks'] ?? json['avg_max_marks'] ?? json['max_marks'];
    final updatedRaw = json['updated_at'] ?? json['last_updated'];
    final photoRaw =
      json['profile_photo_base64'] ?? json['profilePhotoBase64'] ?? json['avatar'];

    final parsedAveragePercentage = averageRaw is num
      ? averageRaw.toDouble()
      : double.tryParse((averageRaw ?? '').toString()) ?? 0;
    final parsedAverageScore = averageScoreRaw is num
      ? averageScoreRaw.toDouble()
      : double.tryParse((averageScoreRaw ?? '').toString());
    final parsedAverageMaxMarks = averageMaxMarksRaw is num
      ? averageMaxMarksRaw.toDouble()
      : double.tryParse((averageMaxMarksRaw ?? '').toString());

    final resolvedAverageScore = parsedAverageScore ?? parsedAveragePercentage;
    final resolvedAverageMaxMarks =
      (parsedAverageMaxMarks != null && parsedAverageMaxMarks > 0)
        ? parsedAverageMaxMarks
        : 100.0;

    final attempts = attemptsRaw is num
      ? attemptsRaw.toInt()
      : int.tryParse((attemptsRaw ?? '').toString()) ?? 1;

    return LeaderboardEntry(
      studentName:
          (json['student_name'] ?? json['studentName'] ?? 'Unknown').toString(),
      subject: (json['subject'] ?? '').toString(),
      attempts: attempts,
      averagePercentage: parsedAveragePercentage,
      averageScore: resolvedAverageScore,
      averageMaxMarks: resolvedAverageMaxMarks,
      profilePhotoBase64:
        photoRaw == null ? null : photoRaw.toString().trim().isEmpty ? null : photoRaw.toString(),
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
    required this.averageScore,
    required this.averageMaxMarks,
    this.profilePhotoBase64,
    required this.updatedAt,
  });

  final String studentName;
  final String subject;
  final int attempts;
  final double averagePercentage;
  final double averageScore;
  final double averageMaxMarks;
  final String? profilePhotoBase64;
  final DateTime updatedAt;
}

class LeaderboardSyncBundle {
  const LeaderboardSyncBundle({
    required this.recentResults,
    required this.leaderboard,
  });

  final List<SharedTestResult> recentResults;
  final List<LeaderboardEntry> leaderboard;
}
