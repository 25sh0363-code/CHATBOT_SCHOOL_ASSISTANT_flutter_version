import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B2C42), Color(0xFF13678A), Color(0xFFF5A623)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('School Assistant', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Chat tutor, schedule tests, view calendar, and track performance.'),
                  if (!authService.isGoogleSignInSupported) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Google Sign-In is unavailable on this desktop build. Use Continue As Guest.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: authService.isGoogleSignInSupported
                          ? authService.signInWithGoogle
                          : null,
                      child: const Text('Sign In With Google'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: authService.continueAsGuest,
                      child: const Text('Continue As Guest'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
