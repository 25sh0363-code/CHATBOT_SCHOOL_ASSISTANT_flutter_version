import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/exam_event.dart';
import '../services/exam_automation_service.dart';
import '../services/focus_timer_service.dart';
import '../services/local_store_service.dart';
import '../services/notification_service.dart';

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatDuration(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _calendarDateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

class CountdownAndFocusScreen extends StatefulWidget {
  const CountdownAndFocusScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<CountdownAndFocusScreen> createState() => _CountdownAndFocusScreenState();
}

class _CountdownAndFocusScreenState extends State<CountdownAndFocusScreen> {
  late final ExamAutomationService _examService;
  List<ExamEvent> _exams = <ExamEvent>[];
  bool _loading = true;
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

  // TEMPORARY TEST METHOD - Remove after testing
  Future<void> _scheduleTestNotification() async {
    // ignore: avoid_print
    print('[StudyPlannerScreen] _scheduleTestNotification() ENTRY');
    final enabled = NotificationService.instance.notificationsEnabled;
    // ignore: avoid_print
    print('[StudyPlannerScreen] _scheduleTestNotification pressed, notificationsEnabled=$enabled');
    if (!enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are disabled. Please enable them in system settings.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      // ignore: avoid_print
      print('[StudyPlannerScreen] Permission check failed, aborting test notification');
      return;
    }

    try {
      // ignore: avoid_print
      print('[StudyPlannerScreen] Before calling _examService.scheduleTestNotification()');
      await _examService.scheduleTestNotification();
      // ignore: avoid_print
      print('[StudyPlannerScreen] After calling _examService.scheduleTestNotification()');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test notification scheduled for 15 seconds from now. Close the app and wait!',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // ignore: avoid_print
      print('[StudyPlannerScreen] scheduleTestNotification() error: $e');
    }
    // ignore: avoid_print
    print('[StudyPlannerScreen] _scheduleTestNotification() EXIT');
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print('[StudyPlannerScreen] build() called');
    final theme = Theme.of(context);

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
                        'Important exams get daily reminders automatically and countdown notifications when approaching. Exams are removed once completed.',
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
                        message: 'Daily reminders + countdown notifications enforced',
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
              const SizedBox(height: 10),
              // TEMPORARY TEST CARD - Remove after testing
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🧪 Test Notifications',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Text(
                        'Test if notifications work when the app is closed. Schedules a test notification for 15 seconds from now.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          // ignore: avoid_print
                          print('[StudyPlannerScreen] Schedule Test Notification button pressed');
                          _scheduleTestNotification();
                        },
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Schedule Test Notification'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}


