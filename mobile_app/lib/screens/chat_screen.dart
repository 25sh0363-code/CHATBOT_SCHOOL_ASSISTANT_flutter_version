import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import '../services/file_selection_service.dart';
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
    final rawMessages =
        (json['messages'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList();
    return _ChatSession(
      id: (json['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: ((json['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['title'] as String).trim()
          : 'Untitled Chat',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages,
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatApiService _chatService;
  late final FileSelectionService _fileSelectionService;
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
    _fileSelectionService = FileSelectionService();
    _storeService = LocalStoreService();
    _loadChatState();
  }

  Future<void> _loadChatState() async {
    final payload = await _storeService.loadChatSessionsPayload();
    final loadedSessions = <_ChatSession>[];
    String? activeId;

    if (payload != null) {
      final rawSessions =
          payload['sessions'] as List<dynamic>? ?? const <dynamic>[];
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

  Future<void> _renameCurrentSession() async {
    final controller = TextEditingController(text: _activeSession.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename chat window'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chat window name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newTitle == null || !mounted) {
      return;
    }

    setState(() {
      _activeSession.title = newTitle;
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
    final historyCount =
        nonErrorMessages.length > 10 ? 10 : nonErrorMessages.length;
    final history = nonErrorMessages
        .skip(nonErrorMessages.length > historyCount
            ? nonErrorMessages.length - historyCount
            : 0)
        .map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
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

    final picked = await _fileSelectionService.pickFiles(
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
      allowMultiple: true,
      dialogLabel: 'Images',
    );

    if (picked.isEmpty) {
      return;
    }

    setState(() {
      _selectedImages.addAll(
        picked
            .map(
              (file) => _SelectedImageAttachment(
                name: file.name,
                base64: base64Encode(file.bytes),
                mimeType: _mimeTypeFromFilename(file.name),
                bytes: file.bytes,
              ),
            )
            .toList(),
      );
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
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lower.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final min = timestamp.minute.toString().padLeft(2, '0');
    final ampm = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  Future<void> _showSessionMenu() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close conversations',
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        final scheme = Theme.of(context).colorScheme;
        final panelWidth = MediaQuery.of(context).size.width * 0.74;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: panelWidth.clamp(260.0, 360.0),
              height: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conversations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _sending
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await _createSession();
                                  },
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('New'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _sending
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await _renameCurrentSession();
                                  },
                            icon: const Icon(Icons.drive_file_rename_outline),
                            label: const Text('Rename'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _sending
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await _deleteCurrentSession();
                                  },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _sessions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            final selected = session.id == _activeSessionId;
                            return ListTile(
                              tileColor: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.42)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await _switchSession(session.id);
                              },
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${session.messages.length} messages',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: selected
                                  ? Icon(
                                      Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
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
    final scheme = theme.colorScheme;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.86;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child:
                        Icon(Icons.smart_toy_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _activeSession.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Conversations',
                    onPressed: _showSessionMenu,
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (_messages.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearCurrentChat,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear chat'),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Start with a question.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final align = msg.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft;
                          final bgColor = msg.isUser
                              ? scheme.primaryContainer
                              : msg.isError
                                  ? const Color(0xFFFFE4E4)
                                  : scheme.surface;
                          final textColor = msg.isUser
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface;

                          return Align(
                            alignment: align,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: maxBubbleWidth.clamp(290.0, 760.0),
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!msg.isUser)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'SINOVATE',
                                        style: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  if (msg.isUser)
                                    SelectableText(
                                      msg.text,
                                      style: TextStyle(
                                          color: textColor, height: 1.4),
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
                                          color: scheme.primary,
                                          fontSize: 15,
                                          height: 1.4,
                                          fontFamily: 'monospace',
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: scheme.outlineVariant),
                                        ),
                                        tableBorder: TableBorder.all(
                                          color: scheme.outline,
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
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatTime(msg.timestamp),
                                      style: TextStyle(
                                        color: textColor.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (!msg.isUser && !msg.isError)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.copy_rounded,
                                          size: 16,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: msg.text));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Copied to clipboard'),
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking...',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} selected',
                  style: TextStyle(color: scheme.onSurfaceVariant),
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
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach file',
                onPressed: _sending ? null : _pickImage,
                icon: const Icon(Icons.attach_file_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask anything...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
