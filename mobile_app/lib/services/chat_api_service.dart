import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatApiService {
  ChatApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<String> generateNotes({
    required String topic,
    required String details,
    List<NoteGenerationAttachment> attachments = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/notes/generate');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic': topic,
        'details': details,
        'attachments': attachments
            .map((a) => {
                  'name': a.name,
                  'base64_data': a.base64Data,
                  'mime_type': a.mimeType,
                })
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final note = data['note'];
    if (note is! String || note.trim().isEmpty) {
      throw Exception('Invalid note response from backend.');
    }
    return note;
  }

  Future<String> generateMindMap({
    required String topic,
    required String details,
    List<NoteGenerationAttachment> attachments = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/mindmap/generate');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic': topic,
        'details': details,
        'attachments': attachments
            .map((a) => {
                  'name': a.name,
                  'base64_data': a.base64Data,
                  'mime_type': a.mimeType,
                })
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final mindMap = data['mind_map'];
    if (mindMap is! String || mindMap.trim().isEmpty) {
      throw Exception('Invalid mind map response from backend.');
    }
    return mindMap;
  }

  Future<String> sendMessage(String question, {List<Map<String, String>>? history}) async {
    final uri = Uri.parse('$baseUrl/chat');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
        'history': history ?? [],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _readAnswer(data);
  }

  Future<String> sendMessageWithImage({
    required String question,
    required String imageBase64,
    required String mimeType,
    List<Map<String, String>>? history,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/image');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
        'image_base64': imageBase64,
        'mime_type': mimeType,
        'history': history ?? [],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _readAnswer(data);
  }

  String _readAnswer(Map<String, dynamic> data) {
    final answer = data['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw Exception('Invalid response from backend.');
    }
    return answer;
  }

  Future<bool> checkHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'];
    final vectorReady = data['vector_ready'];
    return status == 'ok' && vectorReady == true;
  }
}

class NoteGenerationAttachment {
  const NoteGenerationAttachment({
    required this.name,
    required this.base64Data,
    required this.mimeType,
  });

  final String name;
  final String base64Data;
  final String mimeType;
}
