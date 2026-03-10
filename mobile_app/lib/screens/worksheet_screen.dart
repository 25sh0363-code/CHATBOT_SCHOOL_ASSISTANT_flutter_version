import 'package:flutter/material.dart';

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
  final TextEditingController _subjectController = TextEditingController(text: 'Physics');
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '5');
  final TextEditingController _questionsController = TextEditingController();

  final ChatApiService _chatService = ChatApiService(baseUrl: AppConfig.backendBaseUrl);

  List<WorksheetRecord> _worksheets = <WorksheetRecord>[];
  bool _generating = false;

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
          const SnackBar(content: Text('Enter a topic first to generate questions.')),
        );
      }
      return;
    }

    setState(() => _generating = true);
    try {
      final prompt =
          'Create $count school-level $subject worksheet questions on topic: $topic. '
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
    final lines = _questionsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (subject.isEmpty || topic.isEmpty || lines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject, topic, and at least one question are required.'),
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
                  Text('Worksheet Maker', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Worksheet title'),
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
                    decoration: const InputDecoration(labelText: 'Question count for AI draft'),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
          ),
          const SizedBox(height: 12),
          Card(
            child: _worksheets.isEmpty
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
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(question),
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
