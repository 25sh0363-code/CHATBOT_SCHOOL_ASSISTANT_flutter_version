import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/home_screen.dart';
import 'screens/notes_library_screen.dart';
import 'screens/sinovate_splash_screen.dart';
import 'screens/worksheets_library_screen.dart';
import 'services/focus_timer_service.dart';
import 'services/journey_task_overlay_service.dart';
import 'services/local_store_service.dart';
import 'theme/app_theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final isSubWindow = args.isNotEmpty && args.first == 'multi_window';

  if ((Platform.isMacOS || Platform.isWindows) && !isSubWindow) {
    const mobileFrame = Size(675, 1200);
    await windowManager.ensureInitialized();
    final windowOptions = WindowOptions(
      size: mobileFrame,
      minimumSize: mobileFrame,
      maximumSize: mobileFrame,
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  if (isSubWindow) {
    final windowId = args.length > 1 ? int.tryParse(args[1]) : null;
    final payload = args.length > 2 ? args.sublist(2).join(' ') : '';
    Map<String, dynamic> decoded = <String, dynamic>{};
    if (payload.isNotEmpty) {
      try {
        final parsed = jsonDecode(payload);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        }
      } catch (_) {
        decoded = <String, dynamic>{};
      }
    }
    runApp(_ReferenceResourceWindowApp(
      windowId: windowId ?? 0,
      payload: decoded,
    ));
    return;
  }

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
    await FocusTimerService.instance.initialize(storeService: _storeService);
    final enabled = await _storeService.loadDarkModeEnabled();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
      _initializing = false;
    });
  }

  Future<void> _toggleTheme() async {
    final isDark = _themeMode == ThemeMode.dark;
    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = nextMode);
    await _storeService.saveDarkModeEnabled(nextMode == ThemeMode.dark);
  }

  void _handleFocusCompletion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null) return;

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
                      const Icon(Icons.emoji_events_rounded,
                          size: 64, color: Colors.amber),
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
    });
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
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const _FocusTimerOverlay(),
            const _JourneyTaskOverlay(),
          ],
        );
      },
      home: _initializing
          ? const SinovateSplashScreen()
          : HomeScreen(
              isDarkMode: _themeMode == ThemeMode.dark,
              onToggleTheme: _toggleTheme,
            ),
    );
  }
}

class _ReferenceResourceWindowApp extends StatelessWidget {
  const _ReferenceResourceWindowApp({
    required this.windowId,
    required this.payload,
  });

  final int windowId;
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final initialTab =
        payload['initialTab']?.toString() == 'worksheets' ? 1 : 0;
    final includeNotes = payload['includeNotes'] != false;
    final includeWorksheets = payload['includeWorksheets'] != false;
    final themeMode = payload['themeMode']?.toString() == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;
    final scaffoldColor = themeMode == ThemeMode.dark
      ? AppTheme.darkTheme.scaffoldBackgroundColor
      : AppTheme.lightTheme.scaffoldBackgroundColor;
    final tabs = <({String label, IconData icon, Widget child})>[];
    final store = LocalStoreService();
    if (includeNotes) {
      tabs.add((
        label: 'Notes',
        icon: Icons.menu_book_outlined,
        child: NotesLibraryScreen(storeService: store),
      ));
    }
    if (includeWorksheets) {
      tabs.add((
        label: 'Worksheets',
        icon: Icons.assignment_outlined,
        child: WorksheetsLibraryScreen(storeService: store),
      ));
    }

    final safeInitial = tabs.isEmpty ? 0 : initialTab.clamp(0, tabs.length - 1);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: tabs.isEmpty
          ? Scaffold(
              backgroundColor: scaffoldColor,
              appBar: AppBar(
                title: const Text('Reference Window'),
                actions: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () =>
                        WindowController.fromWindowId(windowId).close(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              body: const Center(child: Text('No reference content selected.')),
            )
          : DefaultTabController(
              length: tabs.length,
              initialIndex: safeInitial,
              child: Scaffold(
                backgroundColor: scaffoldColor,
                appBar: AppBar(
                  title: const Text('Referred Resources'),
                  actions: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () =>
                          WindowController.fromWindowId(windowId).close(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                  bottom: TabBar(
                    tabs: [
                      for (final tab in tabs)
                        Tab(icon: Icon(tab.icon), text: tab.label),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [for (final tab in tabs) tab.child],
                ),
              ),
            ),
    );
  }
}

class _FocusTimerOverlay extends StatefulWidget {
  const _FocusTimerOverlay();

  @override
  State<_FocusTimerOverlay> createState() => _FocusTimerOverlayState();
}

class _FocusTimerOverlayState extends State<_FocusTimerOverlay> {
  Offset? _position;
  bool _minimized = false;
  Offset? _lastDragPoint;

  Widget _actionIcon({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _initPositionIfNeeded(BoxConstraints constraints, double width) {
    if (_position != null) {
      return;
    }
    final x = (constraints.maxWidth - width - 12).clamp(0.0, double.infinity);
    _position = Offset(x, 12);
  }

  void _moveBy(Offset delta, BoxConstraints constraints, Size size) {
    final current = _position ?? const Offset(12, 12);
    final maxX =
        (constraints.maxWidth - size.width).clamp(0.0, double.infinity);
    final maxY =
        (constraints.maxHeight - size.height).clamp(0.0, double.infinity);
    final nextX = (current.dx + delta.dx).clamp(0.0, maxX);
    final nextY = (current.dy + delta.dy).clamp(0.0, maxY);
    setState(() {
      _position = Offset(nextX, nextY);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ValueListenableBuilder<Duration>(
            valueListenable: FocusTimerService.instance.remaining,
            builder: (context, remaining, _) {
              if (remaining <= Duration.zero) {
                return const SizedBox.shrink();
              }

              final minutes = remaining.inMinutes.toString().padLeft(2, '0');
              final seconds =
                  (remaining.inSeconds % 60).toString().padLeft(2, '0');

              const expandedSize = Size(188, 228);
              const minimizedSize = Size(72, 52);
              final boxSize = _minimized ? minimizedSize : expandedSize;
              _initPositionIfNeeded(constraints, boxSize.width);

              return Stack(
                children: [
                  Positioned(
                    left: _position?.dx ?? 12,
                    top: _position?.dy ?? 12,
                    child: GestureDetector(
                      onLongPressStart: (details) {
                        _lastDragPoint = details.globalPosition;
                      },
                      onLongPressMoveUpdate: (details) {
                        final previous = _lastDragPoint;
                        if (previous == null) {
                          _lastDragPoint = details.globalPosition;
                          return;
                        }
                        final delta = details.globalPosition - previous;
                        _lastDragPoint = details.globalPosition;
                        _moveBy(delta, constraints, boxSize);
                      },
                      onLongPressEnd: (_) {
                        _lastDragPoint = null;
                      },
                      child: Material(
                        elevation: 10,
                        color: Colors.transparent,
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: boxSize.width,
                          height: boxSize.height,
                          padding: _minimized
                              ? const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                )
                              : const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _minimized
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surface,
                            borderRadius:
                                BorderRadius.circular(_minimized ? 999 : 18),
                            border: Border.all(
                              color: _minimized
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.20,
                                    )
                                  : theme.colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: _minimized ? 14 : 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _minimized
                              ? MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() => _minimized = false);
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '$minutes:$seconds',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme
                                                  .onPrimaryContainer,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Focus Mode',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        _actionIcon(
                                          theme: theme,
                                          icon: Icons.minimize,
                                          onTap: () {
                                            setState(() => _minimized = true);
                                          },
                                        ),
                                        _actionIcon(
                                          theme: theme,
                                          icon: Icons.close_rounded,
                                          onTap: () {
                                            FocusTimerService.instance.stop();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: Text(
                                        '$minutes:$seconds',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Drag to move. Timer keeps running while you use the app.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            FocusTimerService.instance.stop(),
                                        icon: const Icon(
                                            Icons.stop_circle_outlined),
                                        label: const Text('Stop'),
                                        style: const ButtonStyle(
                                          overlayColor: WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _JourneyTaskOverlay extends StatefulWidget {
  const _JourneyTaskOverlay();

  @override
  State<_JourneyTaskOverlay> createState() => _JourneyTaskOverlayState();
}

class _JourneyTaskOverlayState extends State<_JourneyTaskOverlay> {
  Offset? _position;
  bool _minimized = false;
  Offset? _lastDragPoint;

  Widget _actionIcon({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final mm = (safe ~/ 60).toString().padLeft(2, '0');
    final ss = (safe % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _initPositionIfNeeded(BoxConstraints constraints, double width) {
    if (_position != null) {
      return;
    }
    final x = (constraints.maxWidth - width - 12).clamp(0.0, double.infinity);
    _position = Offset(x, 250);
  }

  void _moveBy(Offset delta, BoxConstraints constraints, Size size) {
    final current = _position ?? const Offset(12, 12);
    final maxX =
        (constraints.maxWidth - size.width).clamp(0.0, double.infinity);
    final maxY =
        (constraints.maxHeight - size.height).clamp(0.0, double.infinity);
    final nextX = (current.dx + delta.dx).clamp(0.0, maxX);
    final nextY = (current.dy + delta.dy).clamp(0.0, maxY);
    setState(() {
      _position = Offset(nextX, nextY);
    });
  }

  void _ensurePositionWithinBounds(BoxConstraints constraints, Size size) {
    final current = _position ?? const Offset(12, 12);
    final maxX =
        (constraints.maxWidth - size.width).clamp(0.0, double.infinity);
    final maxY =
        (constraints.maxHeight - size.height).clamp(0.0, double.infinity);
    final clamped = Offset(
      current.dx.clamp(0.0, maxX),
      current.dy.clamp(0.0, maxY),
    );
    if (clamped != current) {
      _position = clamped;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ValueListenableBuilder<JourneyTaskOverlayState>(
            valueListenable: JourneyTaskOverlayService.instance.state,
            builder: (context, overlay, _) {
              if (!overlay.visible) {
                return const SizedBox.shrink();
              }

              final expandedWidth =
                  (constraints.maxWidth - 24).clamp(220.0, 320.0);
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final expandedHeight = textScale > 1.1 ? 268.0 : 244.0;
              final boxSize = _minimized
                  ? const Size(96, 44)
                  : Size(expandedWidth, expandedHeight);
              _initPositionIfNeeded(constraints, boxSize.width);
              _ensurePositionWithinBounds(constraints, boxSize);

              return Stack(
                children: [
                  Positioned(
                    left: _position?.dx ?? 12,
                    top: _position?.dy ?? 250,
                    child: GestureDetector(
                      onLongPressStart: (details) {
                        _lastDragPoint = details.globalPosition;
                      },
                      onLongPressMoveUpdate: (details) {
                        final previous = _lastDragPoint;
                        if (previous == null) {
                          _lastDragPoint = details.globalPosition;
                          return;
                        }
                        final delta = details.globalPosition - previous;
                        _lastDragPoint = details.globalPosition;
                        _moveBy(delta, constraints, boxSize);
                      },
                      onLongPressEnd: (_) {
                        _lastDragPoint = null;
                      },
                      child: Material(
                        elevation: 10,
                        color: Colors.transparent,
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: boxSize.width,
                          height: boxSize.height,
                          padding: _minimized
                              ? const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                )
                              : const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _minimized
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(
                              _minimized ? 999 : 16,
                            ),
                            border: Border.all(
                              color: _minimized
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.20,
                                    )
                                  : theme.colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: _minimized ? 14 : 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _minimized
                                ? MouseRegion(
                                    key: const ValueKey('journey-minimized'),
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() => _minimized = false);
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            color: theme
                                                .colorScheme.onPrimaryContainer,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatDuration(
                                                overlay.remainingSeconds),
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: theme.colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    key: const ValueKey('journey-expanded'),
                                    physics: const ClampingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.task_alt_rounded,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Journey Timer',
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${overlay.taskIndex}/${overlay.totalTasks}',
                                              style:
                                                  theme.textTheme.labelMedium,
                                            ),
                                            _actionIcon(
                                              theme: theme,
                                              icon: Icons.minimize,
                                              onTap: () {
                                                setState(
                                                    () => _minimized = true);
                                              },
                                            ),
                                            _actionIcon(
                                              theme: theme,
                                              icon: Icons.close_rounded,
                                              onTap: () {
                                                JourneyTaskOverlayService
                                                    .instance
                                                    .hide();
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          overlay.taskTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDuration(
                                              overlay.remainingSeconds),
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: overlay.running
                                                ? JourneyTaskOverlayService
                                                    .instance.requestPause
                                                : JourneyTaskOverlayService
                                                    .instance.requestStart,
                                            icon: Icon(overlay.running
                                                ? Icons.pause_circle_outline
                                                : Icons.play_circle_outline),
                                            label: Text(overlay.running
                                                ? 'Pause'
                                                : 'Start'),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: overlay.running
                                                ? JourneyTaskOverlayService
                                                    .instance.requestNextTask
                                                : null,
                                            icon: const Icon(
                                                Icons.skip_next_rounded),
                                            label:
                                                const Text('Complete & Next'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
