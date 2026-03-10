import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/chat_api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  late final ChatApiService _chatService;

  bool _sending = false;
  String _statusText = 'Checking backend...';

  @override
  void initState() {
    super.initState();
    _chatService = ChatApiService(baseUrl: AppConfig.backendBaseUrl);
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    try {
      final ok = await _chatService.checkHealth();
      if (!mounted) return;
      setState(() {
        _statusText = ok
            ? 'Backend connected: ${AppConfig.backendBaseUrl}'
            : 'Backend is reachable but vector DB is not ready';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Cannot reach backend: ${AppConfig.backendBaseUrl}';
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
    });

    try {
      final answer = await _chatService.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Request failed: $e',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB9D8BE)),
            ),
            child: Text(
              _statusText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Ask a chemistry or physics question to start.'),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final align =
                          msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
                      final bgColor = msg.isUser
                          ? const Color(0xFFD6EAF8)
                          : msg.isError
                              ? const Color(0xFFF9D6D6)
                              : const Color(0xFFEFEFEF);

                      return Align(
                        alignment: align,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(msg.text),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Type your question...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}
