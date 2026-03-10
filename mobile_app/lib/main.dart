import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SINOVATE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
