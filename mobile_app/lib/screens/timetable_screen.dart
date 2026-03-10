import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../services/local_store_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<TimetableEntry> _entries = <TimetableEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.storeService.loadTimetableEntries();
    if (!mounted) {
      return;
    }
    setState(() => _entries = items);
  }

  Future<void> _save() async {
    await widget.storeService.saveTimetableEntries(_entries);
  }

  Future<void> _addEntry() async {
    final subject = _subjectController.text.trim();
    final start = _startController.text.trim();
    final end = _endController.text.trim();

    if (subject.isEmpty || start.isEmpty || end.isEmpty) {
      return;
    }

    final entry = TimetableEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      subject: subject,
      date: _selectedDate,
      startTime: start,
      endTime: end,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _entries.add(entry);
      _entries.sort((a, b) => a.date.compareTo(b.date));
    });
    await _save();

    _subjectController.clear();
    _startController.clear();
    _endController.clear();
    _notesController.clear();
  }

  Future<void> _deleteEntry(String id) async {
    setState(() {
      _entries.removeWhere((entry) => entry.id == id);
    });
    await _save();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
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
                  Text('Timetable Maker', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Subject / Class'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: _selectedDate,
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.event),
                    label: Text('Date: ${_selectedDate.toIso8601String().split('T').first}'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startController,
                          decoration: const InputDecoration(labelText: 'Start time (e.g. 09:00)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _endController,
                          decoration: const InputDecoration(labelText: 'End time (e.g. 10:00)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _addEntry, child: const Text('Save timetable entry')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No timetable entries yet'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _entries[index];
                      final date = item.date.toIso8601String().split('T').first;
                      return ListTile(
                        title: Text(item.subject),
                        subtitle: Text('$date   ${item.startTime} - ${item.endTime}${item.notes.isEmpty ? '' : '\n${item.notes}'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteEntry(item.id),
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
