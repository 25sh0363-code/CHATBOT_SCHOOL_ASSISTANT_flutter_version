import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/exam_event.dart';
import '../services/exam_automation_service.dart';
import '../services/focus_timer_service.dart';
import '../services/local_store_service.dart';

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  late final ExamAutomationService _examService;

  List<ExamEvent> _exams = <ExamEvent>[];
  bool _loading = true;

  double _hoursPerDay = 2;
  int _planDays = 7;

  int _focusMinutes = 25;

  @override
  void initState() {
    super.initState();
    _examService = ExamAutomationService(storeService: widget.storeService);
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final exams = await _examService.loadCleanedAndSynced();
      if (!mounted) {
        return;
      }
      setState(() {
        _exams = exams;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addExam() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    DateTime examDate = DateTime.now().add(const Duration(days: 7));

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Important Exam'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Exam title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: examDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          examDate =
                              DateTime(picked.year, picked.month, picked.day);
                        });
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_formatDate(examDate)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Daily reminders are mandatory for important exams.',
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
                    if (titleController.text.trim().isEmpty ||
                        subjectController.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save Exam'),
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

    final now = DateTime.now();
    final newExam = ExamEvent(
      id: '${now.microsecondsSinceEpoch}',
      title: titleController.text.trim(),
      subject: subjectController.text.trim(),
      examDate: examDate,
      createdAt: now,
    );

    final next = [..._exams, newExam]
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
    try {
      await _examService.saveAndSync(next);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _exams = next;
    });

    try {
      await _openGoogleCalendarForExam(newExam);
    } catch (_) {}
  }

  Future<void> _openGoogleCalendarForExam(ExamEvent exam) async {
    final start = _calendarDateOnly(exam.examDate);
    final end = _calendarDateOnly(exam.examDate.add(const Duration(days: 1)));

    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent('Important Exam: ${exam.title}')}'
      '&dates=$start/$end'
      '&details=${Uri.encodeComponent('Subject: ${exam.subject}. One-time exam event.')}',
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _startFocusTimer() async {
    await FocusTimerService.instance.start(Duration(minutes: _focusMinutes));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Focus timer started. You can keep using the app.'),
      ),
    );
  }

  Future<void> _stopFocusTimer() async {
    await FocusTimerService.instance.stop();
  }

  List<_RevisionEntry> _buildRevisionPlan() {
    if (_exams.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = _exams.where((e) {
      final date = DateTime(e.examDate.year, e.examDate.month, e.examDate.day);
      return !date.isBefore(today);
    }).toList();
    if (upcoming.isEmpty) {
      return const [];
    }

    final plan = <_RevisionEntry>[];
    final sessionsPerDay = _hoursPerDay <= 1 ? 1 : (_hoursPerDay.round());

    for (var i = 0; i < _planDays; i++) {
      final day = today.add(Duration(days: i));
      for (var slot = 0; slot < sessionsPerDay; slot++) {
        final targetExam = upcoming[(i + slot) % upcoming.length];
        final daysLeft = targetExam.examDate.difference(day).inDays;
        final intensity = daysLeft <= 3
            ? 'High-priority revision'
            : daysLeft <= 10
                ? 'Core concept revision'
                : 'Concept + practice revision';
        plan.add(
          _RevisionEntry(
            date: day,
            subject: targetExam.subject,
            task: '$intensity for ${targetExam.title}',
            minutes: (60 * _hoursPerDay / sessionsPerDay).round(),
          ),
        );
      }
    }

    return plan;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revisionPlan = _buildRevisionPlan();

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exam Countdown', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Text(
                        'Important exams get daily reminders automatically and are removed once completed.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _addExam,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Important Exam'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_exams.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No upcoming exams yet.'),
                  ),
                )
              else
                ..._exams.map((exam) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final examDate = DateTime(exam.examDate.year,
                      exam.examDate.month, exam.examDate.day);
                  final daysLeft = examDate.difference(today).inDays;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(exam.title),
                      subtitle: Text(
                        '${exam.subject} • ${_formatDate(exam.examDate)} • ${daysLeft == 0 ? 'Today' : '$daysLeft days left'}',
                      ),
                      trailing: const Tooltip(
                        message: 'Daily reminder enforced',
                        child: Icon(Icons.notifications_active_outlined),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Revision Planner',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Hours/day'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 6,
                              divisions: 10,
                              value: _hoursPerDay,
                              label: _hoursPerDay.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() {
                                  _hoursPerDay = value;
                                });
                              },
                            ),
                          ),
                          Text(_hoursPerDay.toStringAsFixed(1)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Plan days'),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('7'),
                            selected: _planDays == 7,
                            onSelected: (_) => setState(() => _planDays = 7),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('14'),
                            selected: _planDays == 14,
                            onSelected: (_) => setState(() => _planDays = 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (revisionPlan.isEmpty)
                        const Text('Add exams to generate your revision plan.')
                      else
                        ...revisionPlan.take(20).map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    _formatDate(entry.date),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${entry.subject}: ${entry.task} (${entry.minutes} min)',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Focus Session Timer',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('25m'),
                            selected: _focusMinutes == 25,
                            onSelected: (_) =>
                                setState(() => _focusMinutes = 25),
                          ),
                          ChoiceChip(
                            label: const Text('45m'),
                            selected: _focusMinutes == 45,
                            onSelected: (_) =>
                                setState(() => _focusMinutes = 45),
                          ),
                          ChoiceChip(
                            label: const Text('60m'),
                            selected: _focusMinutes == 60,
                            onSelected: (_) =>
                                setState(() => _focusMinutes = 60),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<Duration>(
                        valueListenable: FocusTimerService.instance.remaining,
                        builder: (_, remaining, __) {
                          final hasTime = remaining > Duration.zero;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hasTime
                                      ? 'Remaining: ${_formatDuration(remaining)}'
                                      : 'No active focus session',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (!hasTime)
                                FilledButton(
                                  onPressed: _startFocusTimer,
                                  child: const Text('Start'),
                                )
                              else
                                OutlinedButton(
                                  onPressed: _stopFocusTimer,
                                  child: const Text('Stop'),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _calendarDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

}

class _RevisionEntry {
  const _RevisionEntry({
    required this.date,
    required this.subject,
    required this.task,
    required this.minutes,
  });

  final DateTime date;
  final String subject;
  final String task;
  final int minutes;
}
