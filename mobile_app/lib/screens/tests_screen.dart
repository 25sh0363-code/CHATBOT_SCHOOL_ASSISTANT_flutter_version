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
  final TextEditingController _maxMarksController = TextEditingController(text: '100');
  final TextEditingController _scoreController = TextEditingController();
  final List<String> _subjects = ['Physics', 'Chemistry', 'Math', 'Biology', 'Other'];

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

  @override
  Widget build(BuildContext context) {
    final scored = _tests.where((t) => t.percentage != null).toList();

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
                  Text('Add Test', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Test title')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (value) => setState(() => _selectedSubject = value ?? _selectedSubject),
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
                          label: Text('Date: ${_selectedDate.toIso8601String().split('T').first}'),
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
                  FilledButton(onPressed: _addTest, child: const Text('Save test')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Result', style: Theme.of(context).textTheme.titleMedium),
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
                  FilledButton(onPressed: _saveResult, child: const Text('Save result')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance Trend', style: Theme.of(context).textTheme.titleMedium),
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
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < scored.length; i++)
                                      FlSpot(i.toDouble(), scored[i].percentage ?? 0),
                                  ],
                                  isCurved: true,
                                  barWidth: 3,
                                  color: const Color(0xFF13678A),
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
