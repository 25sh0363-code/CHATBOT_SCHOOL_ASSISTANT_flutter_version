import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/homework_task.dart';
import '../models/timetable_entry.dart';
import '../services/local_store_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _reminderController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedKind = HomeworkTask.kindTask;
  List<HomeworkTask> _items = <HomeworkTask>[];

  List<HomeworkTask> get _homeworkItems =>
    _items.where((item) => item.kind == HomeworkTask.kindHomework).toList();

  List<HomeworkTask> get _taskItems =>
    _items.where((item) => item.kind != HomeworkTask.kindHomework).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await widget.storeService.loadHomeworkTasks();
    final entries = await widget.storeService.loadTimetableEntries();

    final legacyTasks = entries
        .where((e) => e.homeworkTask.trim().isNotEmpty)
        .map(
          (e) => HomeworkTask(
            id: 'legacy_${e.id}',
            title: e.homeworkTask.trim(),
            date: e.date,
            reminderTime: e.homeworkReminderTime.trim(),
            kind: HomeworkTask.kindHomework,
            notes: e.notes,
          ),
        )
        .toList();

    var normalizedTasks = tasks;
    if (legacyTasks.isNotEmpty) {
      final normalizedEntries = entries
          .map(
            (e) => TimetableEntry(
              id: e.id,
              subject: e.subject,
              date: e.date,
              startTime: e.startTime,
              endTime: e.endTime,
              notes: e.notes,
              homeworkTask: '',
              homeworkReminderTime: '',
            ),
          )
          .toList();
      normalizedTasks = <HomeworkTask>[...tasks, ...legacyTasks];
      await widget.storeService.saveTimetableEntries(normalizedEntries);
    }

    normalizedTasks.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.reminderTime.compareTo(b.reminderTime);
    });

    if (!mounted) {
      return;
    }
    setState(() {
      _items = normalizedTasks;
    });

    await widget.storeService.saveHomeworkTasks(normalizedTasks);
  }

  Future<void> _saveItems() async {
    await widget.storeService.saveHomeworkTasks(_items);
  }

  Future<void> _openNativeCalendarForReminder(
    String title,
    String reminderTime,
    DateTime date,
  ) async {
    if (reminderTime.isEmpty || !_isValidTime(reminderTime)) {
      return;
    }

    final hour = int.parse(reminderTime.split(':')[0]);
    final minute = int.parse(reminderTime.split(':')[1]);
    final reminderDateTime = date.copyWith(hour: hour, minute: minute);
    final endDateTime = reminderDateTime.add(const Duration(minutes: 30));
    final startStamp = _toCalendarUtcStamp(reminderDateTime);
    final endStamp = _toCalendarUtcStamp(endDateTime);

    try {
      final calendarUrl = Uri.parse(
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=${Uri.encodeComponent(title)}&dates=$startStamp/$endStamp',
      );
      if (await canLaunchUrl(calendarUrl)) {
        await launchUrl(calendarUrl);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No calendar app found on this device.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open calendar: $e')),
      );
    }
  }

  String _toCalendarUtcStamp(DateTime dateTime) {
    final utc = dateTime.toUtc();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${pad(utc.month)}${pad(utc.day)}T${pad(utc.hour)}${pad(utc.minute)}${pad(utc.second)}Z';
  }

  String _dateLabel(DateTime value) {
    return value.toIso8601String().split('T').first;
  }

  Future<void> _addItem() async {
    final title = _titleController.text.trim();
    final reminder = _reminderController.text.trim();
    final notes = _notesController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    if (reminder.isEmpty || !_isValidTime(reminder)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder time must be in HH:MM format.')),
      );
      return;
    }

    final item = HomeworkTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      date: _selectedDate,
      reminderTime: reminder,
      kind: _selectedKind,
      notes: notes,
    );

    setState(() {
      _items.add(item);
      _items.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.reminderTime.compareTo(b.reminderTime);
      });
    });
    await _saveItems();
    await _openNativeCalendarForReminder(item.title, item.reminderTime, item.date);

    _titleController.clear();
    _reminderController.clear();
    _notesController.clear();
  }

  bool _isValidTime(String input) {
    final parts = input.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return false;
    }
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  Future<void> _deleteItem(String id) async {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
    await _saveItems();
  }

  Future<void> _toggleItemComplete(String id, bool completed) async {
    setState(() {
      _items = _items
          .map((item) => item.id == id ? item.copyWith(completed: completed) : item)
          .toList();
    });
    await _saveItems();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reminderController.dispose();
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
                  Text('Timetable Planner', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedKind,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: HomeworkTask.kindTask,
                        child: Text('Task'),
                      ),
                      DropdownMenuItem(
                        value: HomeworkTask.kindHomework,
                        child: Text('Homework'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _selectedKind = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: _selectedKind == HomeworkTask.kindHomework
                          ? 'Homework title'
                          : 'Task title',
                    ),
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
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Date: ${_dateLabel(_selectedDate)}'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reminderController,
                    decoration: const InputDecoration(labelText: 'Reminder time (HH:MM)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: _selectedKind == HomeworkTask.kindHomework
                          ? 'Homework notes (optional)'
                          : 'Task notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _addItem,
                    child: const Text('Save and open calendar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _homeworkItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No homework yet'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _homeworkItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _homeworkItems[index];
                      final date = _dateLabel(item.date);
                      return CheckboxListTile(
                        value: item.completed,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          _toggleItemComplete(item.id, value);
                        },
                        title: Text(
                          item.title,
                          style: TextStyle(
                            decoration:
                                item.completed ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          '$date   Reminder ${item.reminderTime}${item.notes.isEmpty ? '' : '\n${item.notes}'}',
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteItem(item.id),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _taskItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No tasks yet'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _taskItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _taskItems[index];
                      final date = _dateLabel(item.date);
                      return CheckboxListTile(
                        value: item.completed,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          _toggleItemComplete(item.id, value);
                        },
                        title: Text(
                          item.title,
                          style: TextStyle(
                            decoration:
                                item.completed ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          '$date   Reminder ${item.reminderTime}${item.notes.isEmpty ? '' : '\n${item.notes}'}',
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteItem(item.id),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
