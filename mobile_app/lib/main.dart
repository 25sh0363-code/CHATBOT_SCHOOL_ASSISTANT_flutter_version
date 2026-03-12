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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode _themeMode = ThemeMode.light;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    FocusTimerService.instance.completionEvents
        .addListener(_handleFocusCompletion);
    _initializeApp();
  }

  @override
  void dispose() {
    FocusTimerService.instance.completionEvents
        .removeListener(_handleFocusCompletion);
    super.dispose();
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

  void _handleFocusCompletion() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 64,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Focus Complete!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Great work. Time for a short break.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  'You finished your focus session. Step away, hydrate, and come back strong.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Awesome!'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
