import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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
  List<TestRecord> _tests = [];
  List<HomeworkTask> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tests = await widget.storeService.loadTests();
    final items = await widget.storeService.loadHomeworkTasks();
    setState(() {
      _tests = tests;
      _items = items;
    });
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
    final tests = _testsForDay(_selectedDay);
    final items = _itemsForDay(_selectedDay);
    final homework =
        items.where((item) => item.kind == HomeworkTask.kindHomework).toList();
    final tasks =
        items.where((item) => item.kind != HomeworkTask.kindHomework).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
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
                calendarStyle: const CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Color(0xFFF5A623),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: Card(
              child: (tests.isEmpty && homework.isEmpty && tasks.isEmpty)
                  ? const Center(
                      child:
                          Text('No tests, tasks or homework for selected day'),
                    )
                  : ListView(
                      children: [
                        if (tests.isNotEmpty)
                          const ListTile(
                            title: Text('Tests',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        for (final item in tests)
                          ListTile(
                            title: Text(item.title),
                            subtitle: Text(item.subject),
                            trailing:
                                Text('Max ${item.maxMarks.toStringAsFixed(0)}'),
                          ),
                        if (homework.isNotEmpty)
                          const ListTile(
                            title: Text('Homework',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        for (final item in homework)
                          ListTile(
                            title: Text(item.title),
                            subtitle: Text(item.notes.isEmpty
                                ? 'Homework item'
                                : item.notes),
                            trailing: Text(item.reminderTime),
                          ),
                        if (tasks.isNotEmpty)
                          const ListTile(
                            title: Text('Tasks',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        for (final item in tasks)
                          ListTile(
                            title: Text(item.title),
                            subtitle: Text(
                                item.notes.isEmpty ? 'Task item' : item.notes),
                            trailing: Text(item.reminderTime),
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
