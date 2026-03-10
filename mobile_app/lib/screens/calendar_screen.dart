import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.storeService.loadTests();
    setState(() => _tests = items);
  }

  List<TestRecord> _eventsForDay(DateTime day) {
    return _tests.where((test) {
      return test.testDate.year == day.year &&
          test.testDate.month == day.month &&
          test.testDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _eventsForDay(_selectedDay);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TableCalendar<TestRecord>(
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
              child: events.isEmpty
                  ? const Center(child: Text('No tests scheduled for selected day'))
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final item = events[index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(item.subject),
                          trailing: Text('Max ${item.maxMarks.toStringAsFixed(0)}'),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
