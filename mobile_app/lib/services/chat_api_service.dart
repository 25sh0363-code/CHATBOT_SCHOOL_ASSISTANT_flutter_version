import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatApiService {
  ChatApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<String> sendMessage(String question) async {
    final uri = Uri.parse('$baseUrl/chat');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question}),
    );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
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
