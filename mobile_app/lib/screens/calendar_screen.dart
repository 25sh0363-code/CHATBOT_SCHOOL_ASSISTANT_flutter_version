import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/test_record.dart';
import '../models/timetable_entry.dart';
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
  List<TimetableEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tests = await widget.storeService.loadTests();
    final entries = await widget.storeService.loadTimetableEntries();
    setState(() {
      _tests = tests;
      _entries = entries;
    });
  }

  List<TestRecord> _testsForDay(DateTime day) {
    return _tests.where((test) {
      return test.testDate.year == day.year &&
          test.testDate.month == day.month &&
          test.testDate.day == day.day;
    }).toList();
  }

  List<TimetableEntry> _entriesForDay(DateTime day) {
    return _entries.where((entry) {
      return entry.date.year == day.year &&
          entry.date.month == day.month &&
          entry.date.day == day.day;
    }).toList();
  }

  List<Object> _eventsForDay(DateTime day) {
    return <Object>[
      ..._testsForDay(day),
      ..._entriesForDay(day),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tests = _testsForDay(_selectedDay);
    final entries = _entriesForDay(_selectedDay);

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
              child: (tests.isEmpty && entries.isEmpty)
                  ? const Center(child: Text('No tests or timetable entries for selected day'))
                  : ListView(
                      children: [
                        if (tests.isNotEmpty)
                          const ListTile(
                            title: Text('Tests', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        for (final item in tests)
                          ListTile(
                            title: Text(item.title),
                            subtitle: Text(item.subject),
                            trailing: Text('Max ${item.maxMarks.toStringAsFixed(0)}'),
                          ),
                        if (entries.isNotEmpty)
                          const ListTile(
                            title: Text('Timetable', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        for (final entry in entries)
                          ListTile(
                            title: Text(entry.subject),
                            subtitle: Text(entry.notes.isEmpty ? 'Class slot' : entry.notes),
                            trailing: Text('${entry.startTime}-${entry.endTime}'),
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
