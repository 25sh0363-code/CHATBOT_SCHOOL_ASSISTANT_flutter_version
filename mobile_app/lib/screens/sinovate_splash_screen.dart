import 'dart:math' as math;

import 'package:flutter/material.dart';

class SinovateSplashScreen extends StatefulWidget {
  const SinovateSplashScreen({super.key});

  @override
  State<SinovateSplashScreen> createState() => _SinovateSplashScreenState();
}

class _SinovateSplashScreenState extends State<SinovateSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = (math.sin(t * 2 * math.pi) + 1) / 2;

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF060A14),
                            Color(0xFF121E36),
                            Color(0xFF1A314C)
                          ]
                        : const [
                            Color(0xFFE8F3FF),
                            Color(0xFFDDEEFF),
                            Color(0xFFB9D8F2)
                          ],
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.2),
                child: Container(
                  width: 220 + (pulse * 70),
                  height: 220 + (pulse * 70),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        scheme.primary.withValues(alpha: 0.10 + (pulse * 0.12)),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SINOVATE',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                                color: scheme.onSurface,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'School Assistant',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.8),
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: pulse,
                          backgroundColor:
                              scheme.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
