import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/collab_message.dart';
import '../models/collab_room.dart';
import '../models/collab_user.dart';
import '../models/quick_note.dart';
import '../models/worksheet_record.dart';

class CollabApiService {
  CollabApiService({required String baseUrl, http.Client? client})
      : baseUrl = _resolveBaseUrl(baseUrl),
  _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const String _cloudBackendFallback =
      'https://school-assistant-backend.onrender.com';

  static String _resolveBaseUrl(String configured) {
    final trimmed = configured.trim();
    final uri = Uri.tryParse(trimmed);
    final host = (uri?.host ?? '').toLowerCase();
    final compact = trimmed.toLowerCase();
    final isLocalHost =
        host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2' ||
        compact.contains('127.0.0.1') ||
        compact.contains('localhost') ||
        compact.contains('0.0.0.0') ||
        compact.contains('10.0.2.2');

    if (isLocalHost) {
      return _cloudBackendFallback;
    }
    return trimmed;
  }

  Future<CollabUser> signInBasic({
    required String name,
    String email = '',
  }) async {
    final uri = Uri.parse('$baseUrl/collab/auth/basic');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Sign-in failed: ${response.body}');
    }

    return CollabUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<CollabRoom>> getRooms({required String userEmail}) async {
    final uri = Uri.parse('$baseUrl/collab/rooms?user_email=$userEmail');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load collab rooms: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rooms = (data['rooms'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CollabRoom.fromJson)
        .toList();
    return rooms;
  }

  Future<CollabRoom> createRoom({
    required String name,
    required String creatorEmail,
    required String creatorName,
    required bool isPublic,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'creator_email': creatorEmail,
        'creator_name': creatorName,
        'is_public': isPublic,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create collab room: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CollabRoom.fromJson(data['room'] as Map<String, dynamic>);
  }

  Future<CollabRoom> joinRoom({
    required String roomId,
    required String userEmail,
    required String userName,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms/$roomId/join');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_email': userEmail,
        'user_name': userName,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to join room: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CollabRoom.fromJson(data['room'] as Map<String, dynamic>);
  }

  Future<void> deleteRoom({
    required String roomId,
    required String userEmail,
  }) async {
    final uri =
        Uri.parse('$baseUrl/collab/rooms/$roomId?user_email=$userEmail');
    final response = await _client.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete collab room: ${response.body}');
    }
  }

  Future<CollabRoom> removeMember({
    required String roomId,
    required String ownerEmail,
    required String memberEmail,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms/$roomId/remove-member');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_email': ownerEmail,
        'member_email': memberEmail,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove member: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CollabRoom.fromJson(data['room'] as Map<String, dynamic>);
  }

  Future<List<CollabMessage>> getMessages({
    required String roomId,
    required String userEmail,
  }) async {
    final uri = Uri.parse(
        '$baseUrl/collab/rooms/$roomId/messages?user_email=$userEmail');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load messages: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CollabMessage.fromJson)
        .toList();
  }

  Future<void> sendMessage({
    required String roomId,
    required String userEmail,
    required String userName,
    required String text,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms/$roomId/messages');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_email': userEmail,
        'user_name': userName,
        'text': text,
        'message_type': 'text',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<void> shareNote({
    required String roomId,
    required String userEmail,
    required String userName,
    required QuickNote note,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms/$roomId/share-note');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_email': userEmail,
        'user_name': userName,
        'topic': note.topic,
        'content': note.content,
        'attachments': note.attachments
            .map((file) => {
                  'name': file.name,
                  'base64_data': file.base64Data,
                  'mime_type': file.mimeType,
                })
            .toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to share note: ${response.body}');
    }
  }

  Future<void> shareWorksheet({
    required String roomId,
    required String userEmail,
    required String userName,
    required WorksheetRecord worksheet,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms/$roomId/share-worksheet');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_email': userEmail,
        'user_name': userName,
        'title': worksheet.title,
        'subject': worksheet.subject,
        'topic': worksheet.topic,
        'questions': worksheet.questions,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to share worksheet: ${response.body}');
    }
  }

  Future<CollabRoom> updateMeetLink({
    required String roomId,
    required String userEmail,
    required String userName,
    required String meetLink,
  }) async {
    final uri = Uri.parse('$baseUrl/collab/rooms/$roomId/meet');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_email': userEmail,
        'user_name': userName,
        'meet_link': meetLink,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set meet link: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CollabRoom.fromJson(data['room'] as Map<String, dynamic>);
  }
}
