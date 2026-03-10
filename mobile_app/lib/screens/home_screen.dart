import 'package:flutter/material.dart';

import '../services/local_store_service.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'tests_screen.dart';
import 'timetable_screen.dart';
import 'worksheet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final LocalStoreService _storeService = LocalStoreService();

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChatScreen(),
      TestsScreen(storeService: _storeService),
      CalendarScreen(storeService: _storeService),
      TimetableScreen(storeService: _storeService),
      WorksheetScreen(storeService: _storeService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome Student'),
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (idx) => setState(() => _index = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Tests'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Worksheet'),
        ],
      ),
    );
  }
}
