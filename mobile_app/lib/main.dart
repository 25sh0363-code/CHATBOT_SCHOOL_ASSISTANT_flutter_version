import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/sinovate_splash_screen.dart';
import 'services/exam_automation_service.dart';
import 'services/focus_timer_service.dart';
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
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await NotificationService.instance.initialize();
    await FocusTimerService.instance.initialize(storeService: _storeService);
    final enabled = await _storeService.loadDarkModeEnabled();
    final examAutomation = ExamAutomationService(storeService: _storeService);
    await examAutomation.loadCleanedAndSynced();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
      _initializing = false;
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
      home: _initializing
          ? const SinovateSplashScreen()
          : HomeScreen(
              isDarkMode: _themeMode == ThemeMode.dark,
              onToggleTheme: _toggleTheme,
            ),
    );
  }
}
