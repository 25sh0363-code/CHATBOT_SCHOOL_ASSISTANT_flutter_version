import 'package:flutter/material.dart';

import '../models/quick_note.dart';
import '../services/local_store_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  List<QuickNote> _notes = <QuickNote>[];

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
    _contentController.clear();
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
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Write your note',
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
                      return ListTile(
                        title: Text(note.topic),
                        subtitle: Text(
                          '${note.content}\nUpdated: ${_formatDateTime(note.updatedAt)}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
