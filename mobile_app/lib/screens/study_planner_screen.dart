import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exam_event.dart';
import '../services/focus_timer_service.dart';
import '../services/local_store_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// _ExamCalendarService
// Creates 3 Google Calendar events per exam:
//   1. Recurring daily from today until 2 days before exam
//   2. Eve of exam — single special event
//   3. Exam day — single special event
// Each call opens Google Calendar once; user taps Save 3 times total.
// ─────────────────────────────────────────────────────────────────────────────

class _ExamCalendarService {
  _ExamCalendarService._();
  static final _ExamCalendarService instance = _ExamCalendarService._();

  Future<void> createAllEvents({
    required String examTitle,
    required String subject,
    required DateTime examDate,
    required int reminderHour,
    required int reminderMinute,
  }) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final examOnly = DateTime(examDate.year, examDate.month, examDate.day);
    final daysLeft = examOnly.difference(todayOnly).inDays;

    // Reminder offset in minutes from midnight (for all-day events)
    final reminderOffset = reminderHour * 60 + reminderMinute;

    // ── Event 1: recurring daily countdown ──────────────────────────────────
    // Runs from today until the day before eve-of-exam (i.e. until examDate - 2).
    // Only created if exam is more than 2 days away.
    if (daysLeft > 2) {
      final recurringStart = todayOnly;
      // UNTIL is exclusive in RRULE, so set it to examDate - 1 day
      // so the last recurring occurrence is examDate - 2 days.
      final recurringUntil = examOnly.subtract(const Duration(days: 1));

      await _openCalendar(
        title: '📚 $examTitle — Exam Countdown',
        description:
            'Subject: $subject\n'
            'Exam date: ${_readable(examOnly)}\n'
            'Daily reminder until 2 days before your exam.',
        startDate: recurringStart,
        endDate: recurringStart.add(const Duration(days: 1)),
        rrule: 'RRULE:FREQ=DAILY;UNTIL=${_dateOnly(recurringUntil)}T000000Z',
        reminderOffset: reminderOffset,
      );
    }

    // ── Event 2: eve of exam ─────────────────────────────────────────────────
    // Only created if exam is at least 1 day away.
    if (daysLeft >= 1) {
      final eveDate = examOnly.subtract(const Duration(days: 1));
      // Only show eve event if it's today or in the future
      if (!eveDate.isBefore(todayOnly)) {
        await _openCalendar(
          title: '⚡ Tomorrow is your $examTitle exam! Last chance to revise!',
          description:
              'Subject: $subject\n'
              'Your exam is TOMORROW — ${_readable(examOnly)}.\n'
              'Prepare everything tonight!',
          startDate: eveDate,
          endDate: eveDate.add(const Duration(days: 1)),
          rrule: null, // single event
          reminderOffset: reminderOffset,
        );
      }
    }

    // ── Event 3: exam day ────────────────────────────────────────────────────
    if (!examOnly.isBefore(todayOnly)) {
      await _openCalendar(
        title: '🎯 TODAY IS YOUR $examTitle EXAM! ALL THE BEST!!!',
        description:
            'Subject: $subject\n'
            'This is it! You\'ve got this. Give it your all! 💪',
        startDate: examOnly,
        endDate: examOnly.add(const Duration(days: 1)),
        rrule: null, // single event
        reminderOffset: reminderOffset,
      );
    }
  }

  Future<void> _openCalendar({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String? rrule,
    required int reminderOffset,
  }) async {
    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${_dateOnly(startDate)}/${_dateOnly(endDate)}',
      'details': description,
      'reminder': reminderOffset.toString(),
    };
    if (rrule != null) params['recur'] = rrule;

    final uri = Uri.https('calendar.google.com', '/calendar/render', params);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Small delay so Calendar has time to open before we fire the next one
      await Future<void>.delayed(const Duration(milliseconds: 800));
    } else {
      throw Exception('Could not open Google Calendar. Is it installed?');
    }
  }

  /// Opens Google Calendar search so the user can find and delete events.
  Future<void> openSearchForDeletion({required String examTitle}) async {
    final uri = Uri.https('calendar.google.com', '/calendar/search', {
      'q': examTitle,
    });
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(
        Uri.parse('https://calendar.google.com'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  String _dateOnly(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  String _readable(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExamStoreService — local persistence wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _ExamStoreService {
  _ExamStoreService({required LocalStoreService storeService})
      : _store = storeService;

  final LocalStoreService _store;

  Future<List<ExamEvent>> loadCleaned() async {
    final exams = await _store.loadExamEvents();
    final cleaned = _removePast(exams);
    if (cleaned.length != exams.length) {
      await _store.saveExamEvents(cleaned);
    }
    return cleaned;
  }

  Future<void> save(List<ExamEvent> exams) async {
    await _store.saveExamEvents(_removePast(exams));
  }

  List<ExamEvent> _removePast(List<ExamEvent> exams) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return exams.where((e) {
      final d = DateTime(e.examDate.year, e.examDate.month, e.examDate.day);
      return !d.isBefore(todayOnly);
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StudyPlannerScreen
// ─────────────────────────────────────────────────────────────────────────────

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  int _reminderHour = 7;
  int _reminderMinute = 0;
  List<ExamEvent> _exams = [];
  bool _loading = true;
  int _focusMinutes = 25;

  late final _ExamStoreService _store;
  final _calendar = _ExamCalendarService.instance;

  @override
  void initState() {
    super.initState();
    _store = _ExamStoreService(storeService: widget.storeService);
    _loadReminderTime();
    _load();
  }

  Future<void> _loadReminderTime() async {
    final hour = await widget.storeService.loadDailyReminderHour();
    final minute = await widget.storeService.loadDailyReminderMinute();
    if (!mounted) return;
    setState(() {
      _reminderHour = hour;
      _reminderMinute = minute;
    });
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked != null && mounted) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
      await widget.storeService.saveDailyReminderTime(
          _reminderHour, _reminderMinute);
    }
  }

  Future<void> _load() async {
    try {
      final exams = await _store.loadCleaned();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addExam() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    DateTime examDate = DateTime.now().add(const Duration(days: 7));

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  decoration:
                      const InputDecoration(labelText: 'Subject'),
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
                    if (picked == null) return;
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
                  'Google Calendar will open 3 times — tap Save each time to set up your countdown reminders.',
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
                    subjectController.text.trim().isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Save Exam'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;

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
      await _store.save(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save exam: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _exams = next);

    // Show instructions snackbar before opening Calendar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Google Calendar will open 3 times. Tap Save each time ✅'),
        duration: Duration(seconds: 4),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _calendar.createAllEvents(
          examTitle: newExam.title,
          subject: newExam.subject,
          examDate: newExam.examDate,
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not open Google Calendar: $e'),
            backgroundColor: Colors.red,
          ));
        }
      }
    });
  }

  Future<void> _deleteExam(ExamEvent exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Exam'),
        content: Text(
          'Remove "${exam.title}" from your list?\n\n'
          "You'll be taken to Google Calendar to delete the reminder events.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final updated = _exams.where((e) => e.id != exam.id).toList();
    try {
      await _store.save(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to remove exam: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _exams = updated);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _calendar.openSearchForDeletion(examTitle: exam.title);
      } catch (_) {}
    });
  }

  Future<void> _startFocusTimer() async {
    await FocusTimerService.instance.start(Duration(minutes: _focusMinutes));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Focus timer started. You can keep using the app.')),
    );
  }

  Future<void> _stopFocusTimer() async {
    await FocusTimerService.instance.stop();
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ── Exam Countdown card ────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exam Countdown',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Text(
                        'Add an exam and 3 Google Calendar reminders are created automatically — '
                        'a daily countdown, an eve-of-exam alert, and an exam-day notification.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Reminder time: ',
                              style: theme.textTheme.bodyMedium),
                          Text(
                            '${_reminderHour.toString().padLeft(2, '0')}:'
                            '${_reminderMinute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _pickReminderTime,
                            icon: const Icon(Icons.access_time),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _addExam,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Important Exam'),
                      ),
                      const SizedBox(height: 18),
                      // ── Focus Timer ──────────────────────────────────
                      Text('Focus Timer',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('25m'),
                            selected: _focusMinutes == 25,
                            onSelected: (_) =>
                                setState(() => _focusMinutes = 25),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('45m'),
                            selected: _focusMinutes == 45,
                            onSelected: (_) =>
                                setState(() => _focusMinutes = 45),
                          ),
                          const SizedBox(width: 8),
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
              // ── Exam list ──────────────────────────────────────────────
              if (_exams.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No upcoming exams yet.'),
                  ),
                )
              else
                ..._exams.map((exam) {
                  final today = DateTime.now();
                  final todayOnly =
                      DateTime(today.year, today.month, today.day);
                  final examOnly = DateTime(exam.examDate.year,
                      exam.examDate.month, exam.examDate.day);
                  final daysLeft = examOnly.difference(todayOnly).inDays;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(exam.title),
                      subtitle: Text(
                        '${exam.subject} • ${_formatDate(exam.examDate)} • '
                        '${daysLeft == 0 ? 'Today! 🎯' : daysLeft == 1 ? 'Tomorrow! ⚡' : '$daysLeft days left'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Re-open all 3 Calendar events
                          IconButton(
                            icon: const Icon(
                                Icons.calendar_month_outlined),
                            tooltip: 'Re-add to Google Calendar',
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Google Calendar will open 3 times. Tap Save each time ✅'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              try {
                                await _calendar.createAllEvents(
                                  examTitle: exam.title,
                                  subject: exam.subject,
                                  examDate: exam.examDate,
                                  reminderHour: _reminderHour,
                                  reminderMinute: _reminderMinute,
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text('$e')));
                                }
                              }
                            },
                          ),
                          // Delete exam
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove exam',
                            onPressed: () => _deleteExam(exam),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
  }
}