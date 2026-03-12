import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/todo_item.dart';
import '../services/chat_api_service.dart';
import '../services/local_store_service.dart';

enum TodoFilter { pending, today, completed }

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoItem> _items = <TodoItem>[];
  TodoFilter _filter = TodoFilter.pending;
  bool _loading = true;
  bool _generating = false;

  late final ChatApiService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatApiService(baseUrl: AppConfig.backendBaseUrl);
    _load();
  }

  Future<void> _load() async {
    final items = await widget.storeService.loadTodoItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await widget.storeService.saveTodoItems(_items);
  }

  Future<void> _upsertItem({TodoItem? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final detailsController = TextEditingController(
      text: existing?.details ?? '',
    );
    DateTime dueDate = existing?.dueDate ?? DateTime.now();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add To-Do' : 'Edit To-Do'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Details (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          dueDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            dueDate.hour,
                            dueDate.minute,
                          );
                        });
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_formatDate(dueDate)),
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
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final title = titleController.text.trim();
    final details = detailsController.text.trim();

    setState(() {
      if (existing == null) {
        final now = DateTime.now();
        _items.add(
          TodoItem(
            id: now.microsecondsSinceEpoch.toString(),
            title: title,
            details: details,
            dueDate: dueDate,
            createdAt: now,
            isCompleted: false,
          ),
        );
      } else {
        _items = _items
            .map(
              (item) => item.id == existing.id
                  ? item.copyWith(
                      title: title,
                      details: details,
                      dueDate: dueDate,
                    )
                  : item,
            )
            .toList();
      }
      _sortItems();
    });

    await _save();
  }

  Future<void> _toggleDone(TodoItem item, bool done) async {
    setState(() {
      _items = _items
          .map(
            (entry) => entry.id == item.id
                ? entry.copyWith(
                    isCompleted: done,
                    completedAt: done ? DateTime.now() : null,
                    clearCompletedAt: !done,
                  )
                : entry,
          )
          .toList();
      _sortItems();
    });
    await _save();
  }

  Future<void> _deleteItem(String id) async {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
    await _save();
  }

  Future<void> _deleteWithConfirm(TodoItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text('"${item.title}" will be removed permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }
    await _deleteItem(item.id);
  }

  Future<void> _clearCompleted() async {
    if (_completedCount == 0) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear completed tasks?'),
          content: Text('This will remove $_completedCount completed tasks.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    setState(() {
      _items.removeWhere((item) => item.isCompleted);
    });
    await _save();
  }

  Future<void> _generateTodosFromContext() async {
    if (_generating) {
      return;
    }

    final subjectController = TextEditingController();
    final topicController = TextEditingController();
    final contextController = TextEditingController();

    final shouldGenerate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Generate To-Do List'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(labelText: 'Topic'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Context',
                    hintText: 'Exam date, weak areas, or instructions',
                  ),
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
                if (subjectController.text.trim().isEmpty ||
                    topicController.text.trim().isEmpty ||
                    contextController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );

    if (shouldGenerate != true) {
      return;
    }

    final subject = subjectController.text.trim();
    final topic = topicController.text.trim();
    final contextText = contextController.text.trim();

    setState(() {
      _generating = true;
    });

    try {
      final response = await _chatService.sendMessage(
        'Create a student to-do list for Subject: $subject. '
        'Topic: $topic. Context: $contextText. '
        'Return only 6-10 concise tasks as plain text, one task per line, no headings, no markdown.',
      );

      final tasks = _parseGeneratedTasks(response);
      if (tasks.isEmpty) {
        throw Exception(
            'No tasks were generated. Please try different context.');
      }

      final now = DateTime.now();
      final generated = <TodoItem>[];
      for (var i = 0; i < tasks.length; i++) {
        final dueDate = DateTime(now.year, now.month, now.day + i);
        generated.add(
          TodoItem(
            id: '${now.microsecondsSinceEpoch}_$i',
            title: tasks[i],
            details: '$subject • $topic',
            dueDate: dueDate,
            createdAt: now,
            isCompleted: false,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _items = [...generated, ..._items];
        _sortItems();
      });
      await _save();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Generated ${generated.length} tasks successfully.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate tasks: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  List<String> _parseGeneratedTasks(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .map((line) => line.replaceFirst(RegExp(r'^\d+[\).:-]?\s*'), ''))
        .map((line) => line.replaceFirst(RegExp(r'^\[[xX\s]\]\s*'), ''))
        .where((line) => line.length >= 4)
        .toList();

    final fallback = raw
        .split(RegExp(r'[.;]'))
        .map((segment) => segment.trim())
        .where((segment) => segment.length >= 10)
        .toList();

    final source = lines.isNotEmpty ? lines : fallback;
    final unique = <String>[];
    for (final task in source) {
      if (!unique.contains(task)) {
        unique.add(task);
      }
      if (unique.length == 10) {
        break;
      }
    }
    return unique;
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (!a.isCompleted) {
        return a.dueDate.compareTo(b.dueDate);
      }
      final aCompleted = a.completedAt ?? a.createdAt;
      final bCompleted = b.completedAt ?? b.createdAt;
      return bCompleted.compareTo(aCompleted);
    });
  }

  List<TodoItem> get _filteredItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filter) {
      case TodoFilter.pending:
        return _items.where((item) => !item.isCompleted).toList();
      case TodoFilter.today:
        return _items.where((item) {
          final date =
              DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
          return !item.isCompleted && date == today;
        }).toList();
      case TodoFilter.completed:
        return _items.where((item) => item.isCompleted).toList();
    }
  }

  int get _pendingCount => _items.where((item) => !item.isCompleted).length;

  int get _completedCount => _items.where((item) => item.isCompleted).length;

  int get _overdueCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _items.where((item) {
      final dueDate =
          DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
      return !item.isCompleted && dueDate.isBefore(today);
    }).length;
  }

  static String _formatDate(DateTime value) {
    final year = value.year;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = _filteredItems;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Planner',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Track tasks, clear your day, and stay in control.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(label: 'Pending', value: _pendingCount),
                  _MetricChip(label: 'Completed', value: _completedCount),
                  _MetricChip(label: 'Overdue', value: _overdueCount),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Pending',
                count: _pendingCount,
                icon: Icons.pending_actions_outlined,
                selected: _filter == TodoFilter.pending,
                onTap: () => setState(() => _filter = TodoFilter.pending),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Today',
                count: _items.where((item) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final itemDate = DateTime(
                    item.dueDate.year,
                    item.dueDate.month,
                    item.dueDate.day,
                  );
                  return !item.isCompleted && itemDate == today;
                }).length,
                icon: Icons.today_outlined,
                selected: _filter == TodoFilter.today,
                onTap: () => setState(() => _filter = TodoFilter.today),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Done',
                count: _completedCount,
                icon: Icons.task_alt_outlined,
                selected: _filter == TodoFilter.completed,
                onTap: () => setState(() => _filter = TodoFilter.completed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _upsertItem(),
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
              ),
              OutlinedButton.icon(
                onPressed: _completedCount == 0 ? null : _clearCompleted,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear Done'),
              ),
              IconButton.filledTonal(
                tooltip: 'Generate tasks',
                onPressed: _generating ? null : _generateTodosFromContext,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : visibleItems.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks here yet.',
                        style: theme.textTheme.titleMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            await _deleteWithConfirm(item);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: theme.colorScheme.errorContainer,
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: Checkbox(
                                value: item.isCompleted,
                                onChanged: (value) {
                                  _toggleDone(item, value ?? false);
                                },
                              ),
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.details.isNotEmpty)
                                    Text(item.details),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Due ${_formatDate(item.dueDate)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _upsertItem(existing: item);
                                    return;
                                  }
                                  if (value == 'delete') {
                                    _deleteWithConfirm(item);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text('$label ($count)'),
    );
  }
}
