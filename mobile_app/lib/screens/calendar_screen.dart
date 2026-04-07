import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/homework_task.dart';
import '../models/test_record.dart';
import '../services/local_store_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<TestRecord> _tests = <TestRecord>[];
  List<HomeworkTask> _items = <HomeworkTask>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tests = await widget.storeService.loadTests();
    final items = await widget.storeService.loadHomeworkTasks();
    if (!mounted) {
      return;
    }
    setState(() {
      _tests = tests;
      _items = items;
    });
  }

  Future<void> _addCalendarItem() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    var selectedDate = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    var selectedTime = const TimeOfDay(hour: 18, minute: 0);
    var selectedKind = HomeworkTask.kindTask;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task / Homework'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
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
                    setDialogState(() {
                      selectedKind = value ?? HomeworkTask.kindTask;
                    });
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    });
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_formatDate(selectedDate)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedTime = picked;
                    });
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_formatTime(selectedTime)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Google Calendar opens after save. Save the event there to enable reminders at your chosen time.',
                  style: TextStyle(fontSize: 12),
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
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) {
      return;
    }

    final reminderTime = _formatTime24(selectedTime);
    final item = HomeworkTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      date: selectedDate,
      reminderTime: reminderTime,
      kind: selectedKind,
      notes: notesController.text.trim(),
    );

    final next = <HomeworkTask>[..._items, item]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.reminderTime.compareTo(b.reminderTime);
      });

    await widget.storeService.saveHomeworkTasks(next);
    if (!mounted) {
      return;
    }

    setState(() {
      _items = next;
      _selectedDay = selectedDate;
      _focusedDay = selectedDate;
    });

    await _openGoogleCalendarForItem(
      item: item,
      timeOfDay: selectedTime,
    );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item added. Google Calendar opened for reminder setup.'),
      ),
    );
  }

  Future<void> _openGoogleCalendarForItem({
    required HomeworkTask item,
    required TimeOfDay timeOfDay,
  }) async {
    final start = DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    final end = start.add(const Duration(hours: 1));
    final typeLabel = item.kind == HomeworkTask.kindHomework ? 'Homework' : 'Task';

    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': '$typeLabel: ${item.title}',
      'dates': '${_formatCalendarDateTime(start)}/${_formatCalendarDateTime(end)}',
      'details': item.notes.isEmpty ? '$typeLabel reminder from school assistant app.' : item.notes,
      'reminder': '0',
    };

    final uri = Uri.https('calendar.google.com', '/calendar/render', params);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatCalendarDateTime(DateTime dt) => '${dt.year}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}'
      'T'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '00';

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatTime24(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  List<TestRecord> _testsForDay(DateTime day) {
    return _tests.where((test) {
      return test.testDate.year == day.year &&
          test.testDate.month == day.month &&
          test.testDate.day == day.day;
    }).toList();
  }

  List<HomeworkTask> _itemsForDay(DateTime day) {
    return _items.where((item) {
      return item.date.year == day.year &&
          item.date.month == day.month &&
          item.date.day == day.day;
    }).toList();
  }

  List<Object> _eventsForDay(DateTime day) {
    return <Object>[
      ..._testsForDay(day),
      ..._itemsForDay(day),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tests = _testsForDay(_selectedDay);
    final items = _itemsForDay(_selectedDay);
    final homework =
        items.where((item) => item.kind == HomeworkTask.kindHomework).toList();
    final tasks =
        items.where((item) => item.kind != HomeworkTask.kindHomework).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track tests, homework, and tasks in one place.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Add task/homework',
                onPressed: _addCalendarItem,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniBadge(
                label: 'Tests',
                value: '${tests.length}',
                icon: Icons.quiz_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniBadge(
                label: 'Homework',
                value: '${homework.length}',
                icon: Icons.book_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniBadge(
                label: 'Tasks',
                value: '${tasks.length}',
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TableCalendar<Object>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,
              sixWeekMonthsEnforced: false,
              rowHeight: 42,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              eventLoader: _eventsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DayAgendaCard(
          title: 'Tests',
          icon: Icons.quiz_rounded,
          items: tests
              .map(
                (item) => _AgendaTile(
                  title: item.title,
                  subtitle: item.subject,
                  trailing: 'Max ${item.maxMarks.toStringAsFixed(0)}',
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        _DayAgendaCard(
          title: 'Homework',
          icon: Icons.book_rounded,
          items: homework
              .map(
                (item) => _AgendaTile(
                  title: item.title,
                  subtitle: item.notes.isEmpty ? 'Homework item' : item.notes,
                  trailing: item.reminderTime,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        _DayAgendaCard(
          title: 'Tasks',
          icon: Icons.check_circle_rounded,
          items: tasks
              .map(
                (item) => _AgendaTile(
                  title: item.title,
                  subtitle: item.notes.isEmpty ? 'Task item' : item.notes,
                  trailing: item.reminderTime,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DayAgendaCard extends StatelessWidget {
  const _DayAgendaCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_AgendaTile> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'No $title for the selected day.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.trailing,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgendaTile {
  const _AgendaTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;
}
