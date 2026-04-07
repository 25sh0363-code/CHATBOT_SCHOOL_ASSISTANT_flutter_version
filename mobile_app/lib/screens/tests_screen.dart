import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/test_record.dart';
import '../services/local_store_service.dart';

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _maxMarksController =
      TextEditingController(text: '100');
  final TextEditingController _scoreController = TextEditingController();
  final List<String> _subjects = [
    'Physics',
    'Chemistry',
    'Math',
    'Biology',
    'Other'
  ];

  DateTime _selectedDate = DateTime.now();
  String _selectedSubject = 'Physics';
  List<TestRecord> _tests = [];
  String? _selectedTestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.storeService.loadTests();
    setState(() {
      _tests = items;
      _selectedTestId = items.isEmpty ? null : items.last.id;
    });
  }

  Future<void> _saveTests() async {
    await widget.storeService.saveTests(_tests);
  }

  Future<void> _addTest() async {
    final title = _titleController.text.trim();
    final maxMarks = double.tryParse(_maxMarksController.text.trim());
    if (title.isEmpty || maxMarks == null || maxMarks <= 0) {
      return;
    }

    final test = TestRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      subject: _selectedSubject,
      testDate: _selectedDate,
      maxMarks: maxMarks,
    );

    setState(() {
      _tests.add(test);
      _tests.sort((a, b) => a.testDate.compareTo(b.testDate));
      _selectedTestId = test.id;
    });
    await _saveTests();
    _titleController.clear();
  }

  Future<void> _saveResult() async {
    if (_selectedTestId == null) {
      return;
    }

    final score = double.tryParse(_scoreController.text.trim());
    if (score == null) {
      return;
    }

    setState(() {
      _tests = _tests.map((test) {
        if (test.id != _selectedTestId) {
          return test;
        }
        return test.copyWith(score: max(0, min(score, test.maxMarks)));
      }).toList();
    });

    await _saveTests();
    _scoreController.clear();
  }

  Future<void> _deleteTest(String id) async {
    setState(() {
      _tests.removeWhere((test) => test.id == id);
      if (_selectedTestId == id) {
        _selectedTestId = _tests.isEmpty ? null : _tests.last.id;
      }
    });
    await _saveTests();
  }

  Future<void> _editTest(TestRecord test) async {
    final titleController = TextEditingController(text: test.title);
    final maxMarksController = TextEditingController(
      text: test.maxMarks.toStringAsFixed(
          test.maxMarks.truncateToDouble() == test.maxMarks ? 0 : 2),
    );
    DateTime selectedDate = test.testDate;
    String selectedSubject = test.subject;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Test'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Test title'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubject,
                      items: _subjects
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSubject = value ?? selectedSubject;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                initialDate: selectedDate,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.event),
                            label: Text(
                              selectedDate.toIso8601String().split('T').first,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxMarksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max marks'),
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
                    final title = titleController.text.trim();
                    final maxMarks =
                        double.tryParse(maxMarksController.text.trim());
                    if (title.isEmpty || maxMarks == null || maxMarks <= 0) {
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

    if (didSave != true) {
      return;
    }

    final title = titleController.text.trim();
    final maxMarks = double.tryParse(maxMarksController.text.trim());
    if (title.isEmpty || maxMarks == null || maxMarks <= 0) {
      return;
    }

    setState(() {
      _tests = _tests.map((item) {
        if (item.id != test.id) {
          return item;
        }
        final adjustedScore = item.score == null
            ? null
            : max(0.0, min(item.score!, maxMarks)).toDouble();
        return item.copyWith(
          title: title,
          subject: selectedSubject,
          testDate: selectedDate,
          maxMarks: maxMarks,
          score: adjustedScore,
        );
      }).toList();
      _tests.sort((a, b) => a.testDate.compareTo(b.testDate));
    });

    await _saveTests();
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Color _subjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return const Color(0xFF2C7BE5);
      case 'chemistry':
        return const Color(0xFF00A6A6);
      case 'math':
        return const Color(0xFF5F6AF2);
      case 'biology':
        return const Color(0xFF2DA562);
      default:
        return const Color(0xFF4B6CB7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scored = _tests.where((t) => t.percentage != null).toList();
    final avg = scored.isEmpty
        ? 0.0
        : scored.map((t) => t.percentage!).reduce((a, b) => a + b) /
            scored.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Performance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track tests, record scores, and visualize progress in one place.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _statTile(
                        label: 'Total tests',
                        value: '${_tests.length}',
                        icon: Icons.fact_check_outlined,
                      ),
                      _statTile(
                        label: 'Scored tests',
                        value: '${scored.length}',
                        icon: Icons.query_stats,
                      ),
                      _statTile(
                        label: 'Avg score',
                        value: scored.isEmpty
                            ? '--'
                            : '${avg.toStringAsFixed(1)}%',
                        icon: Icons.auto_graph,
                      ),
                      _statTile(
                        label: 'Next date',
                        value: _tests.isEmpty
                            ? '--'
                            : _tests.first.testDate
                                .toIso8601String()
                                .split('T')
                                .first,
                        icon: Icons.event_available,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Test',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Test title')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubject,
                  items: _subjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) => setState(
                      () => _selectedSubject = value ?? _selectedSubject),
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
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
                        label: Text(
                            'Date: ${_selectedDate.toIso8601String().split('T').first}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _maxMarksController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max marks'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _addTest,
                    child: const Text('Save test'),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Result',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTestId,
                  items: _tests
                      .map(
                        (test) => DropdownMenuItem(
                          value: test.id,
                          child: Text('${test.title} (${test.subject})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedTestId = value),
                  decoration: const InputDecoration(labelText: 'Select test'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Score'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _saveResult, child: const Text('Save result')),
                ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Tests',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_tests.isEmpty)
                  const Text('No tests added yet')
                else
                  Column(
                    children: _tests
                        .map(
                          (test) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _subjectColor(test.subject)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              title: Text(test.title),
                              subtitle: Text(
                                '${test.subject} | ${test.testDate.toIso8601String().split('T').first} | '
                                '${test.score?.toStringAsFixed(1) ?? '-'} / ${test.maxMarks.toStringAsFixed(1)}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editTest(test);
                                    return;
                                  }

                                  if (value == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete test?'),
                                        content: Text(
                                          'This will remove "${test.title}" permanently.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteTest(test.id);
                                    }
                                  }
                                },
                                itemBuilder: (context) => const [
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
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Performance Trend',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: scored.isEmpty
                      ? const Center(child: Text('No scored tests yet'))
                      : LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: 100,
                            gridData: const FlGridData(show: true),
                            titlesData: const FlTitlesData(
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (int i = 0; i < scored.length; i++)
                                    FlSpot(i.toDouble(),
                                        scored[i].percentage ?? 0),
                                ],
                                isCurved: true,
                                barWidth: 3,
                                color: scheme.primary,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
