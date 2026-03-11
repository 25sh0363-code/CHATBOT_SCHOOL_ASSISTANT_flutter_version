import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/local_store_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchoolAssistantApp());
}

class SchoolAssistantApp extends StatefulWidget {
  const SchoolAssistantApp({super.key});

  @override
  State<SchoolAssistantApp> createState() => _SchoolAssistantAppState();
}

class _SchoolAssistantAppState extends State<SchoolAssistantApp> {
  final LocalStoreService _storeService = LocalStoreService();
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.instance.initialize();
    final entries = await _storeService.loadTimetableEntries();
    await NotificationService.instance.syncTimetableNotifications(entries);
  }

  Future<void> _loadTheme() async {
    final enabled = await _storeService.loadDarkModeEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final isDark = _themeMode == ThemeMode.dark;
    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = nextMode;
    });
    await _storeService.saveDarkModeEnabled(nextMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SINOVATE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: HomeScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
