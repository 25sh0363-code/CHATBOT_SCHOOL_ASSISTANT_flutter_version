import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/worksheet_record.dart';
import '../services/chat_api_service.dart';
import '../services/local_store_service.dart';

class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController =
      TextEditingController(text: 'Physics');
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _countController =
      TextEditingController(text: '5');
  final TextEditingController _questionsController = TextEditingController();

  final ChatApiService _chatService =
      ChatApiService(baseUrl: AppConfig.backendBaseUrl);
  static const List<String> _difficultyOptions = <String>[
    'Easy',
    'Medium',
    'Hard',
    'Mixed',
  ];
  static const List<String> _questionTypeOptions = <String>[
    'MCQs',
    'PYQs',
    'Short Answer',
    '3 Marks',
    '4 Marks',
    '5 Marks',
  ];

  List<WorksheetRecord> _worksheets = <WorksheetRecord>[];
  bool _generating = false;
  String _selectedDifficulty = 'Medium';
  final Set<String> _selectedQuestionTypes = <String>{'MCQs'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.storeService.loadWorksheets();
    if (!mounted) {
      return;
    }
    setState(() => _worksheets = items);
  }

  Future<void> _save() async {
    await widget.storeService.saveWorksheets(_worksheets);
  }

  Future<void> _generateDraft() async {
    final topic = _topicController.text.trim();
    final subject = _subjectController.text.trim();
    final count = int.tryParse(_countController.text.trim()) ?? 5;
    if (topic.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter a topic first to generate questions.')),
        );
      }
      return;
    }

    setState(() => _generating = true);
    try {
      final typesText = _selectedQuestionTypes.join(', ');
      final prompt =
          'Create $count school-level $subject worksheet questions on topic: $topic. '
          'Difficulty: $_selectedDifficulty. '
          'Question types to include: $typesText. '
          'Return only numbered questions in plain text.';
      final answer = await _chatService.sendMessage(prompt);
      if (!mounted) {
        return;
      }
      setState(() => _questionsController.text = answer.trim());
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft generation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _saveWorksheet() async {
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final topic = _topicController.text.trim();
    final lines = _splitIntoQuestions(_questionsController.text);

    if (subject.isEmpty || topic.isEmpty || lines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Subject, topic, and at least one question are required.'),
          ),
        );
      }
      return;
    }

    final effectiveTitle = title.isEmpty ? '$subject Worksheet: $topic' : title;

    final item = WorksheetRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: effectiveTitle,
      subject: subject,
      topic: topic,
      createdAt: DateTime.now(),
      questions: lines,
    );

    try {
      setState(() {
        _worksheets.insert(0, item);
      });
      await _save();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      return;
    }

    _titleController.clear();
    _topicController.clear();
    _questionsController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worksheet saved successfully.')),
      );
    }
  }

  List<String> _splitIntoQuestions(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return <String>[];
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final questionStart = RegExp(
      r'^(?:Q(?:uestion)?\s*\d+|\d+)[\).:\-]\s+|^\(\d+\)\s+',
      caseSensitive: false,
    );
    final optionLine = RegExp(
      r'^(?:[A-Da-d]|[ivxIVX]{1,4})[\).]\s+|^Option\s+[A-Da-d][\s:.-]',
      caseSensitive: false,
    );

    final grouped = <String>[];
    final buffer = <String>[];

    void flush() {
      if (buffer.isEmpty) {
        return;
      }
      grouped.add(buffer.join('\n').trim());
      buffer.clear();
    }

    var sawExplicitQuestion = false;
    for (final line in lines) {
      final isQuestionStart = questionStart.hasMatch(line);
      final isOption = optionLine.hasMatch(line);

      if (isQuestionStart) {
        sawExplicitQuestion = true;
        flush();
        buffer.add(line);
        continue;
      }

      if (buffer.isEmpty) {
        buffer.add(line);
      } else {
        // Attach options/sub-lines to the current question block.
        buffer.add(line);
        if (!sawExplicitQuestion && !isOption) {
          flush();
        }
      }
    }

    flush();
    return grouped.where((q) => q.trim().isNotEmpty).toList();
  }

  Future<void> _deleteWorksheet(String id) async {
    setState(() {
      _worksheets.removeWhere((item) => item.id == id);
    });
    await _save();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _countController.dispose();
    _questionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget sectionCard(Widget child) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Worksheet Studio',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Draft, customize, and save practice sheets in minutes.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          sectionCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Worksheet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  decoration:
                      const InputDecoration(labelText: 'Worksheet title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(labelText: 'Topic'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Question count for AI draft'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDifficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: _difficultyOptions
                      .map(
                        (level) => DropdownMenuItem<String>(
                          value: level,
                          child: Text(level),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedDifficulty = value);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Question types (choose multiple)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _questionTypeOptions.map((type) {
                    final selected = _selectedQuestionTypes.contains(type);
                    return FilterChip(
                      label: Text(type),
                      selected: selected,
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _selectedQuestionTypes.add(type);
                            return;
                          }
                          if (_selectedQuestionTypes.length > 1) {
                            _selectedQuestionTypes.remove(type);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _generating ? null : _generateDraft,
                        child: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Generate Draft'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveWorksheet,
                        child: const Text('Save Worksheet'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _questionsController,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Questions (one per line)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          sectionCard(
            _worksheets.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No worksheets saved yet'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _worksheets.length,
                    itemBuilder: (context, index) {
                      final item = _worksheets[index];
                      return ExpansionTile(
                        title: Text(item.title),
                        subtitle: Text('${item.subject} | ${item.topic}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteWorksheet(item.id),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final question in item.questions)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: scheme.primary
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: SelectableText(question),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy,
                                                size: 18),
                                            tooltip: 'Copy question',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(
                                                  text: question));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Question copied to clipboard'),
                                                  duration:
                                                      Duration(seconds: 1),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
