import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import '../services/local_store_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _SelectedImageAttachment {
  const _SelectedImageAttachment({
    required this.name,
    required this.base64,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String base64;
  final String mimeType;
  final Uint8List bytes;
}

class _ChatSession {
  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  final String id;
  String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory _ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    return _ChatSession(
      id: (json['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: ((json['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['title'] as String).trim()
          : 'Untitled Chat',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      messages: rawMessages,
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatApiService _chatService;
  late final LocalStoreService _storeService;

  bool _sending = false;
  bool _loading = true;
  final List<_SelectedImageAttachment> _selectedImages =
      <_SelectedImageAttachment>[];

  final List<_ChatSession> _sessions = <_ChatSession>[];
  String? _activeSessionId;

  _ChatSession get _activeSession {
    for (final session in _sessions) {
      if (session.id == _activeSessionId) {
        return session;
      }
    }
    final fallback = _ChatSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New Chat',
      createdAt: DateTime.now(),
      messages: <ChatMessage>[],
    );
    _sessions.insert(0, fallback);
    _activeSessionId = fallback.id;
    return fallback;
  }

  List<ChatMessage> get _messages => _activeSession.messages;

  @override
  void initState() {
    super.initState();
    _chatService = ChatApiService(baseUrl: AppConfig.backendBaseUrl);
    _storeService = LocalStoreService();
    _loadChatState();
  }

  Future<void> _loadChatState() async {
    final payload = await _storeService.loadChatSessionsPayload();
    final loadedSessions = <_ChatSession>[];
    String? activeId;

    if (payload != null) {
      final rawSessions = payload['sessions'] as List<dynamic>? ?? const <dynamic>[];
      for (final item in rawSessions) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          loadedSessions.add(_ChatSession.fromJson(item));
        } catch (_) {
          // Skip malformed session entries to keep app usable.
        }
      }
      activeId = payload['activeSessionId'] as String?;
    }

    if (loadedSessions.isEmpty) {
      final legacyMessages = await _storeService.loadChatHistory();
      loadedSessions.add(
        _ChatSession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: legacyMessages.isEmpty ? 'New Chat' : 'Previous Chat',
          createdAt: DateTime.now(),
          messages: legacyMessages,
        ),
      );
    }

    final activeExists = loadedSessions.any((s) => s.id == activeId);
    if (!activeExists) {
      activeId = loadedSessions.first.id;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _sessions
        ..clear()
        ..addAll(loadedSessions);
      _activeSessionId = activeId;
      _loading = false;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _persistChatState() async {
    final payload = {
      'activeSessionId': _activeSessionId,
      'sessions': _sessions.map((s) => s.toJson()).toList(),
    };
    await _storeService.saveChatSessionsPayload(payload);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    });
  }

  Future<void> _createSession() async {
    final session = _ChatSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New Chat',
      createdAt: DateTime.now(),
      messages: <ChatMessage>[],
    );
    setState(() {
      _sessions.insert(0, session);
      _activeSessionId = session.id;
      _selectedImages.clear();
      _controller.clear();
    });
    await _persistChatState();
  }

  Future<void> _switchSession(String sessionId) async {
    if (_activeSessionId == sessionId) {
      return;
    }
    setState(() {
      _activeSessionId = sessionId;
      _selectedImages.clear();
      _controller.clear();
    });
    _scrollToBottom(animated: false);
    await _persistChatState();
  }

  Future<void> _deleteCurrentSession() async {
    if (_sessions.length <= 1) {
      setState(() {
        _messages.clear();
      });
      await _persistChatState();
      return;
    }

    final currentId = _activeSession.id;
    setState(() {
      _sessions.removeWhere((s) => s.id == currentId);
      _activeSessionId = _sessions.first.id;
      _selectedImages.clear();
      _controller.clear();
    });
    await _persistChatState();
  }

  Future<void> _clearCurrentChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear This Chat'),
        content: const Text('Delete all messages in this chat window?'),
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _messages.clear();
    });
    await _persistChatState();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _selectedImages.isEmpty) || _sending) {
      return;
    }

    final hasImages = _selectedImages.isNotEmpty;
    final imagesToSend = List<_SelectedImageAttachment>.from(_selectedImages);
    final prompt = text.isEmpty
        ? (hasImages && imagesToSend.length > 1
            ? 'Analyze these images.'
            : 'Analyze this image.')
        : text;

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
          text: hasImages
              ? '[${imagesToSend.length} image${imagesToSend.length > 1 ? 's' : ''} attached] $prompt'
              : prompt,
          isUser: true,
        ),
      );
      if (_activeSession.title == 'New Chat' && text.isNotEmpty) {
        _activeSession.title = _smartTitleFromPrompt(text);
      }
      _controller.clear();
      _selectedImages.clear();
    });
    _scrollToBottom();
    await _persistChatState();

    try {
      final answer = hasImages
          ? await _chatService.sendMessageWithImages(
              question: prompt,
              attachments: imagesToSend
                  .map(
                    (image) => NoteGenerationAttachment(
                      name: image.name,
                      base64Data: image.base64,
                      mimeType: image.mimeType,
                    ),
                  )
                  .toList(),
              history: history,
            )
          : await _chatService.sendMessage(prompt, history: history);

      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(ChatMessage(text: answer, isUser: false));
      });
      _scrollToBottom();
      await _persistChatState();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Request failed: $e',
            isUser: false,
            isError: true,
          ),
        );
      });
      _scrollToBottom();
      await _persistChatState();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  String _smartTitleFromPrompt(String prompt) {
    final cleaned = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 26) {
      return cleaned;
    }
    return '${cleaned.substring(0, 26).trim()}...';
  }

  Future<void> _pickImage() async {
    if (_sending) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = <_SelectedImageAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      picked.add(
        _SelectedImageAttachment(
          name: file.name,
          base64: base64Encode(bytes),
          mimeType: _mimeTypeFromFilename(file.name),
          bytes: bytes,
        ),
      );
    }

    if (picked.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected image bytes.')),
      );
      return;
    }

    setState(() {
      _selectedImages.addAll(picked);
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

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final min = timestamp.minute.toString().padLeft(2, '0');
    final ampm = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.86;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2832) : const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF324759) : const Color(0xFFD8E3EF),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _activeSessionId,
                      hint: const Text('Choose chat window'),
                      items: _sessions
                          .map(
                            (session) => DropdownMenuItem<String>(
                              value: session.id,
                              child: Text(session.title, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _sending
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              _switchSession(value);
                            },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'New chat window',
                onPressed: _sending ? null : _createSession,
                icon: const Icon(Icons.add_comment_outlined),
              ),
              IconButton(
                tooltip: 'Delete current chat window',
                onPressed: _sending ? null : _deleteCurrentSession,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _clearCurrentChat,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear This Chat'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Start this chat window with a chemistry or physics question.'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final align =
                              msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
                          final bgColor = msg.isUser
                              ? (isDark
                                  ? const Color(0xFF1A3D57)
                                  : const Color(0xFFD7EEFF))
                              : msg.isError
                                  ? (isDark
                                      ? const Color(0xFF5A2428)
                                      : const Color(0xFFF9D6D6))
                                  : (isDark
                                      ? const Color(0xFF1F2C38)
                                      : const Color(0xFFF8FAFC));
                          final textColor = msg.isUser
                              ? (isDark ? Colors.white : const Color(0xFF10212E))
                              : msg.isError
                                  ? (isDark
                                      ? const Color(0xFFFFD8D8)
                                      : const Color(0xFF4A1111))
                                  : (isDark
                                      ? const Color(0xFFEAF3FB)
                                      : const Color(0xFF1D2A35));

                          return Align(
                            alignment: align,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: maxBubbleWidth.clamp(290.0, 760.0),
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: msg.isUser
                                      ? (isDark
                                          ? const Color(0xFF2B5A7A)
                                          : const Color(0xFFB8DDF7))
                                      : (isDark
                                          ? const Color(0xFF31414E)
                                          : const Color(0xFFDCE6EF)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: msg.isUser
                                            ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                            : theme.colorScheme.secondary.withValues(alpha: 0.16),
                                        child: Icon(
                                          msg.isUser ? Icons.person : Icons.smart_toy_outlined,
                                          size: 14,
                                          color: msg.isUser
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg.isUser ? 'You' : 'SINOVATE AI',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatTime(msg.timestamp),
                                        style: TextStyle(
                                          color: textColor.withValues(alpha: 0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (msg.isUser)
                                    SelectableText(
                                      msg.text,
                                      style: TextStyle(color: textColor, height: 1.4),
                                    )
                                  else
                                    MarkdownBody(
                                      data: msg.text,
                                      selectable: true,
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          height: 1.48,
                                        ),
                                        h1: TextStyle(
                                          color: textColor,
                                          fontSize: 21,
                                          height: 1.35,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        h2: TextStyle(
                                          color: textColor,
                                          fontSize: 19,
                                          height: 1.35,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        h3: TextStyle(
                                          color: textColor,
                                          fontSize: 17,
                                          height: 1.35,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        listBullet: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                        listIndent: 20,
                                        blockSpacing: 10,
                                        code: TextStyle(
                                          color: textColor,
                                          fontSize: 15,
                                          height: 1.4,
                                          backgroundColor:
                                              isDark ? Colors.black26 : Colors.grey[200],
                                          fontFamily: 'monospace',
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: isDark ? Colors.black26 : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        tableBorder: TableBorder.all(
                                          color: textColor.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                        tableHead: TextStyle(
                                          color: textColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        tableBody: TextStyle(
                                          color: textColor,
                                          fontSize: 15,
                                          height: 1.35,
                                        ),
                                        blockquote: TextStyle(
                                          color: textColor.withValues(alpha: 0.8),
                                          fontSize: 15,
                                          height: 1.4,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        blockquoteDecoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF2D4355)
                                              : const Color(0xFFDCEEFF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        blockquotePadding: const EdgeInsets.all(12),
                                        blockquoteAlign: WrapAlignment.start,
                                        horizontalRuleDecoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF5C7284)
                                              : const Color(0xFF9CB6CB),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
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
          if (_sending)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF223140) : const Color(0xFFE8F2FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Generating response...'),
                ],
              ),
            ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedImages.clear());
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = _selectedImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          image.bytes,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedImages.map((image) => image.name).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach images',
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
