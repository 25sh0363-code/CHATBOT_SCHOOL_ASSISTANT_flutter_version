import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _showPreview = false;

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
    final hasAttachments = _attachments.isNotEmpty;
    if (topic.isEmpty || (content.isEmpty && !hasAttachments)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a topic and either note text or at least one attachment.'),
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final note = QuickNote(
      id: now.microsecondsSinceEpoch.toString(),
      topic: topic,
      content: content,
      createdAt: now,
      updatedAt: now,
      attachments: _attachments
          .map(
            (item) => QuickNoteAttachment(
              name: item.name,
              base64Data: item.base64Data,
              mimeType: item.mimeType,
            ),
          )
          .toList(),
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
      _showPreview = false;
    });
  }

  Future<void> _pickAttachments() async {
    if (_generating) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'doc',
        'docx',
        'txt',
      ],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final selected = <_SelectedAttachment>[];
    final failed = <String>[];
    for (final file in result.files) {
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && (file.path?.isNotEmpty ?? false)) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }

      if (bytes == null || bytes.isEmpty) {
        failed.add(file.name);
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

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read selected files. Please try smaller files or different files.'),
        ),
      );
      return;
    }

    setState(() {
      _attachments
        ..clear()
        ..addAll(selected);
    });

    if (failed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some files were skipped: ${failed.join(', ')}'),
        ),
      );
    }
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
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }

  IconData _iconForMimeType(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime.contains('pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (mime.startsWith('image/')) {
      return Icons.image_outlined;
    }
    if (mime.contains('word') || mime.contains('document') || mime.contains('text')) {
      return Icons.description_outlined;
    }
    return Icons.attach_file_outlined;
  }

  Future<File> _materializeAttachment(
    String noteId,
    QuickNoteAttachment attachment,
  ) async {
    final cacheDir = await getTemporaryDirectory();
    final root = Directory('${cacheDir.path}/quick_note_files');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final safeName = attachment.name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final file = File('${root.path}/${noteId}_$safeName');
    if (!await file.exists()) {
      final bytes = base64Decode(attachment.base64Data);
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  Future<void> _openAttachment(QuickNote note, QuickNoteAttachment attachment) async {
    try {
      final file = await _materializeAttachment(note.id, attachment);
      final result = await OpenFilex.open(file.path, type: attachment.mimeType);
      if (!mounted) {
        return;
      }
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${attachment.name}')),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${attachment.name}')),
      );
    }
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
      setState(() {
        _contentController.text = note;
        _showPreview = true;
      });
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
                        label: const Text('Add Files'),
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
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Edit'),
                        selected: !_showPreview,
                        onSelected: (_) {
                          setState(() {
                            _showPreview = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Preview'),
                        selected: _showPreview,
                        onSelected: (_) {
                          setState(() {
                            _showPreview = true;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_showPreview)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _contentController.text.trim().isEmpty
                          ? Text(
                              'No content to preview yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          : MarkdownBody(
                              data: _contentController.text,
                              selectable: true,
                              extensionSet: md.ExtensionSet.gitHubFlavored,
                              styleSheet: MarkdownStyleSheet(
                                p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                                h1: Theme.of(context).textTheme.titleLarge,
                                h2: Theme.of(context).textTheme.titleMedium,
                                h3: Theme.of(context).textTheme.titleSmall,
                                listBullet: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                    )
                  else
                    TextField(
                      controller: _contentController,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Generated note / manual note',
                        alignLabelWithHint: true,
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
                          MarkdownBody(
                            data: note.content,
                            selectable: true,
                            extensionSet: md.ExtensionSet.gitHubFlavored,
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                              h1: Theme.of(context).textTheme.titleLarge,
                              h2: Theme.of(context).textTheme.titleMedium,
                              h3: Theme.of(context).textTheme.titleSmall,
                              listBullet: Theme.of(context).textTheme.bodyLarge,
                              blockSpacing: 10,
                              tableBorder: TableBorder.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.4),
                              ),
                              tableHead: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              tableBody: Theme.of(context).textTheme.bodyLarge,
                              code: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontFamily: 'monospace',
                                    height: 1.4,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (note.attachments.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: note.attachments
                                  .map(
                                    (attachment) => ActionChip(
                                      avatar: Icon(
                                        _iconForMimeType(attachment.mimeType),
                                        size: 16,
                                      ),
                                      label: Text(attachment.name),
                                      onPressed: () => _openAttachment(note, attachment),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
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
