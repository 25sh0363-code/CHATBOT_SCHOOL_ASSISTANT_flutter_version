import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
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
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ValueListenableBuilder<bool>(
        valueListenable: _authService.isSignedIn,
        builder: (context, signedIn, _) {
          if (!signedIn) {
            return LoginScreen(authService: _authService);
          }
          return HomeScreen(authService: _authService);
        },
      ),
    );
  }
}
