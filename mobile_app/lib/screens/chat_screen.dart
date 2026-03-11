import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import '../services/local_store_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[];
  late final ChatApiService _chatService;
  late final LocalStoreService _storeService;

  bool _sending = false;
  bool _loading = true;
  String? _selectedImageBase64;
  String? _selectedImageName;
  String _selectedMimeType = 'image/jpeg';

  @override
  void initState() {
    super.initState();
    _chatService = ChatApiService(baseUrl: AppConfig.backendBaseUrl);
    _storeService = LocalStoreService();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final history = await _storeService.loadChatHistory();
    if (mounted) {
      setState(() {
        _messages.addAll(history);
        _loading = false;
      });
    }
  }

  Future<void> _saveChatHistory() async {
    await _storeService.saveChatHistory(_messages);
  }

  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear all chat messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _messages.clear();
      });
      await _storeService.clearChatHistory();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _selectedImageBase64 == null) || _sending) {
      return;
    }

    final hasImage = _selectedImageBase64 != null;
    final imageName = _selectedImageName;
    final imageBase64 = _selectedImageBase64;
    final mimeType = _selectedMimeType;
    final prompt = text.isEmpty ? 'Analyze this image.' : text;

    // Get conversation history BEFORE adding the current message (last 10 messages)
    final nonErrorMessages = _messages.where((m) => !m.isError).toList();
    final historyCount = nonErrorMessages.length > 10 ? 10 : nonErrorMessages.length;
    final history = nonErrorMessages
        .skip(nonErrorMessages.length > historyCount ? nonErrorMessages.length - historyCount : 0)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    setState(() {
      _sending = true;
      _messages.add(
        ChatMessage(
          text: hasImage && imageName != null ? '[Image: $imageName] $prompt' : prompt,
          isUser: true,
        ),
      );
      _controller.clear();
      _selectedImageBase64 = null;
      _selectedImageName = null;
      _selectedMimeType = 'image/jpeg';
    });

    try {

      final answer = hasImage && imageBase64 != null
          ? await _chatService.sendMessageWithImage(
              question: prompt,
              imageBase64: imageBase64,
              mimeType: mimeType,
              history: history,
            )
          : await _chatService.sendMessage(prompt, history: history);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: answer, isUser: false));
      });
      await _saveChatHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
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

  Future<void> _pickImage() async {
    if (_sending) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected image bytes.')),
      );
      return;
    }

    setState(() {
      _selectedImageBase64 = base64Encode(bytes);
      _selectedImageName = file.name;
      _selectedMimeType = _mimeTypeFromFilename(file.name);
    });
  }

  String _mimeTypeFromFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _clearChatHistory,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Clear Chat'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
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
                        ? (isDark ? const Color(0xFF1E3A4E) : const Color(0xFFD6EAF8))
                        : msg.isError
                          ? (isDark
                            ? const Color(0xFF5A2428)
                            : const Color(0xFFF9D6D6))
                          : (isDark ? const Color(0xFF22303C) : const Color(0xFFEFEFEF));
                      final textColor = msg.isUser
                        ? (isDark ? Colors.white : const Color(0xFF10212E))
                        : msg.isError
                          ? (isDark ? const Color(0xFFFFD8D8) : const Color(0xFF4A1111))
                          : (isDark ? const Color(0xFFEAF3FB) : const Color(0xFF1D2A35));

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                msg.text,
                                style: TextStyle(color: textColor),
                              ),
                              if (!msg.isUser && !msg.isError)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: msg.text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Copied to clipboard'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_selectedImageName != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.image_outlined, size: 18),
                label: Text(_selectedImageName!),
                onDeleted: () {
                  setState(() {
                    _selectedImageBase64 = null;
                    _selectedImageName = null;
                    _selectedMimeType = 'image/jpeg';
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach image',
                onPressed: _sending ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
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
