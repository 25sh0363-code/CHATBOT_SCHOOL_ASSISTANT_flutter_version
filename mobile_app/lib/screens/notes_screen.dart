import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../config/app_config.dart';
import '../models/quick_note.dart';
import '../services/chat_api_service.dart';
import '../services/local_store_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ChatApiService _chatApiService =
      ChatApiService(baseUrl: AppConfig.backendBaseUrl);

  List<QuickNote> _notes = <QuickNote>[];
  final List<_SelectedAttachment> _attachments = <_SelectedAttachment>[];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.storeService.loadQuickNotes();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = items;
    });
  }

  Future<void> _save() async {
    await widget.storeService.saveQuickNotes(_notes);
  }

  Future<void> _addNote() async {
    final topic = _topicController.text.trim();
    final content = _contentController.text.trim();
    if (topic.isEmpty || content.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final note = QuickNote(
      id: now.microsecondsSinceEpoch.toString(),
      topic: topic,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _notes.insert(0, note);
    });
    await _save();

    _topicController.clear();
    _detailsController.clear();
    _contentController.clear();
    setState(() {
      _attachments.clear();
    });
  }

  Future<void> _pickAttachments() async {
    if (_generating) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final selected = <_SelectedAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      selected.add(
        _SelectedAttachment(
          name: file.name,
          mimeType: _mimeTypeFromFilename(file.name),
          base64Data: base64Encode(bytes),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _attachments
        ..clear()
        ..addAll(selected);
    });
  }

  String _mimeTypeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<void> _generateNote() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty || _generating) {
      return;
    }

    setState(() {
      _generating = true;
    });

    try {
      final note = await _chatApiService.generateNotes(
        topic: topic,
        details: _detailsController.text.trim(),
        attachments: _attachments
            .map(
              (item) => NoteGenerationAttachment(
                name: item.name,
                base64Data: item.base64Data,
                mimeType: item.mimeType,
              ),
            )
            .toList(),
      );
      if (!mounted) {
        return;
      }
      _contentController.text = note;
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate notes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  Future<void> _editNote(QuickNote note) async {
    final topicController = TextEditingController(text: note.topic);
    final contentController = TextEditingController(text: note.content);

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(labelText: 'Topic'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final topic = topicController.text.trim();
                final content = contentController.text.trim();
                if (topic.isEmpty || content.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (didSave != true) {
      return;
    }

    final topic = topicController.text.trim();
    final content = contentController.text.trim();
    if (topic.isEmpty || content.isEmpty) {
      return;
    }

    setState(() {
      _notes = _notes
          .map((item) => item.id == note.id
              ? item.copyWith(
                  topic: topic,
                  content: content,
                  updatedAt: DateTime.now(),
                )
              : item)
          .toList();
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
    await _save();
  }

  Future<void> _deleteNote(String id) async {
    setState(() {
      _notes.removeWhere((note) => note.id == id);
    });
    await _save();
  }

  String _formatDateTime(DateTime value) {
    final date = value.toIso8601String().split('T').first;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }

  @override
  void dispose() {
    _topicController.dispose();
    _detailsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Notes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(labelText: 'Topic'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _detailsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Details / instructions (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickAttachments,
                        icon: const Icon(Icons.attach_file_outlined),
                        label: const Text('Add PDF/Image'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _generating ? null : _generateNote,
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Generate Notes'),
                        ),
                      ),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _attachments
                          .map(
                            (file) => Chip(
                              label: Text(file.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Generated note / manual note',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _addNote,
                    child: const Text('Save note'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _notes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No notes yet. Add a quick note to revise later.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return ExpansionTile(
                        title: Text(note.topic),
                        subtitle: Text('Updated: ${_formatDateTime(note.updatedAt)}'),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 64,
                              child: MarkdownBody(
                                data: note.content,
                                selectable: true,
                                extensionSet: md.ExtensionSet.gitHubFlavored,
                                styleSheet: MarkdownStyleSheet(
                                  p: Theme.of(context).textTheme.bodyMedium,
                                  tableBorder: TableBorder.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.4),
                                  ),
                                  tableHead: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  tableBody: Theme.of(context).textTheme.bodyMedium,
                                  code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editNote(note),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteNote(note.id),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SelectedAttachment {
  const _SelectedAttachment({
    required this.name,
    required this.base64Data,
    required this.mimeType,
  });

  final String name;
  final String base64Data;
  final String mimeType;
}
