import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/local_store_service.dart';
import 'app_settings_screen.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'collab_screen.dart';
import 'exams_hub_screen.dart';
import 'learning_journey_library_screen.dart';
import 'mind_map_landscape_screen.dart';
import 'notes_library_screen.dart';
import 'results_leaderboard_screen.dart';
import 'study_planner_screen.dart';
import 'worksheets_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalStoreService _storeService = LocalStoreService();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeDashboard(
        storeService: _storeService,
        onOpenNova: () => setState(() => _index = 1),
        onOpenLeaderboard: () => setState(() => _index = 2),
        onOpenSettings: () => setState(() => _index = 3),
        onOpenExamsHub: () => _push(
          'Exams Hub',
          ExamsHubScreen(storeService: _storeService),
        ),
        onOpenNotes: () => _push(
          'My Notes',
          NotesLibraryScreen(storeService: _storeService),
        ),
        onOpenWorksheets: () => _push(
          'Worksheets',
          WorksheetsLibraryScreen(storeService: _storeService),
        ),
        onOpenCollabHub: () => _push(
          'Collab Hub',
          CollabScreen(storeService: _storeService),
        ),
        onOpenCalendar: () => _push(
          'Calendar',
          CalendarScreen(storeService: _storeService),
        ),
        onOpenMindMap: () => _push(
          'Mind Map',
          MindMapLandscapeScreen(storeService: _storeService),
        ),
        onOpenFocusSession: () => _push(
          'Focus Session',
          StudyPlannerScreen(
            storeService: _storeService,
            showExamCountdown: false,
            showFocusTimer: true,
          ),
        ),
        onOpenLearningJourneys: () => _push(
          'Learning Journey',
          LearningJourneyLibraryScreen(storeService: _storeService),
        ),
      ),
      const ChatScreen(),
      ResultsLeaderboardScreen(storeService: _storeService),
      AppSettingsScreen(
        storeService: _storeService,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'SINOVATE',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_rounded),
            label: 'Leaderboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _push(String title, Widget child) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FeatureHostPage(title: title, child: child),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({
    required this.storeService,
    required this.onOpenNova,
    required this.onOpenLeaderboard,
    required this.onOpenSettings,
    required this.onOpenExamsHub,
    required this.onOpenNotes,
    required this.onOpenWorksheets,
    required this.onOpenCollabHub,
    required this.onOpenCalendar,
    required this.onOpenMindMap,
    required this.onOpenFocusSession,
    required this.onOpenLearningJourneys,
  });

  final LocalStoreService storeService;
  final VoidCallback onOpenNova;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenExamsHub;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenWorksheets;
  final VoidCallback onOpenCollabHub;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenMindMap;
  final VoidCallback onOpenFocusSession;
  final VoidCallback onOpenLearningJourneys;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  int _upcomingExamCount = 0;
  int _loginStreakDays = 0;
  String _name = 'Student';
  Uint8List? _avatarBytes;
  List<_ChatWindowPreview> _recentChatWindows = <_ChatWindowPreview>[];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final tests = await widget.storeService.loadTests();
    final name = await widget.storeService.loadProfileName();
    final photoBase64 = await widget.storeService.loadProfilePhotoBase64();
    final chatPayload = await widget.storeService.loadChatSessionsPayload();

    if (!mounted) {
      return;
    }

    Uint8List? avatar;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        avatar = base64Decode(photoBase64);
      } catch (_) {
        avatar = null;
      }
    }

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final windowEnd = todayOnly.add(const Duration(days: 10));

    setState(() {
      _name = name;
      _avatarBytes = avatar;
      _upcomingExamCount = tests.where((test) {
        final testDate = DateTime(
          test.testDate.year,
          test.testDate.month,
          test.testDate.day,
        );
        return !testDate.isBefore(todayOnly) && !testDate.isAfter(windowEnd);
      }).length;
      _recentChatWindows = _extractRecentChatWindows(chatPayload);
      _loginStreakDays = _calculateLoginStreak(chatPayload);
    });
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    }
    if (hour >= 12 && hour < 20) {
      return 'Good evening';
    }
    return 'Good night';
  }

  List<_ChatWindowPreview> _extractRecentChatWindows(
    Map<String, dynamic>? payload,
  ) {
    if (payload == null) {
      return <_ChatWindowPreview>[];
    }

    final rawSessions =
        payload['sessions'] as List<dynamic>? ?? const <dynamic>[];
    final items = <_ChatWindowPreview>[];

    for (final raw in rawSessions) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final titleRaw = (raw['title'] ?? 'Untitled Chat').toString().trim();
      final title = titleRaw.isEmpty ? 'Untitled Chat' : titleRaw;
      final createdAt =
          DateTime.tryParse((raw['createdAt'] ?? '').toString()) ??
              DateTime.now();
      final rawMessages =
          raw['messages'] as List<dynamic>? ?? const <dynamic>[];

      String subtitle = 'No messages yet';
      if (rawMessages.isNotEmpty) {
        final lastMessage = rawMessages.last;
        if (lastMessage is Map<String, dynamic>) {
          final text = (lastMessage['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            subtitle = text;
          }
        }
      }

      items.add(
        _ChatWindowPreview(
          title: title,
          subtitle: subtitle,
          createdAt: createdAt,
          messageCount: rawMessages.length,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(5).toList();
  }

  int _calculateLoginStreak(Map<String, dynamic>? payload) {
    if (payload == null) {
      return 0;
    }

    final activeDates = <DateTime>{};
    final rawSessions =
        payload['sessions'] as List<dynamic>? ?? const <dynamic>[];

    for (final raw in rawSessions) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final createdAt = DateTime.tryParse((raw['createdAt'] ?? '').toString());
      if (createdAt != null) {
        activeDates
            .add(DateTime(createdAt.year, createdAt.month, createdAt.day));
      }

      final rawMessages =
          raw['messages'] as List<dynamic>? ?? const <dynamic>[];
      for (final rawMessage in rawMessages) {
        if (rawMessage is! Map<String, dynamic>) {
          continue;
        }
        final stamp =
            DateTime.tryParse((rawMessage['timestamp'] ?? '').toString());
        if (stamp != null) {
          activeDates.add(DateTime(stamp.year, stamp.month, stamp.day));
        }
      }
    }

    if (activeDates.isEmpty) {
      return 0;
    }

    var streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final dayOnly = DateTime(cursor.year, cursor.month, cursor.day);
      if (!activeDates.contains(dayOnly)) {
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _formatChatTime(DateTime value) {
    final h24 = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$minute $ampm';
  }

  Future<void> _showFeaturesMenu() async {
    final features = <_FeatureShortcut>[
      _FeatureShortcut(
          'Notes', Icons.sticky_note_2_rounded, widget.onOpenNotes),
      _FeatureShortcut(
        'Worksheets',
        Icons.assignment_rounded,
        widget.onOpenWorksheets,
      ),
      _FeatureShortcut(
          'Collab Hub', Icons.groups_rounded, widget.onOpenCollabHub),
      _FeatureShortcut(
          'Calendar', Icons.calendar_month_rounded, widget.onOpenCalendar),
      _FeatureShortcut('Mind Map', Icons.hub_rounded, widget.onOpenMindMap),
      _FeatureShortcut(
          'Focus Session', Icons.timer_rounded, widget.onOpenFocusSession),
      _FeatureShortcut(
          'Exams Hub', Icons.school_rounded, widget.onOpenExamsHub),
      _FeatureShortcut(
        'Learning Journeys',
        Icons.route_rounded,
        widget.onOpenLearningJourneys,
      ),
      _FeatureShortcut(
        'Leaderboard',
        Icons.leaderboard_rounded,
        widget.onOpenLeaderboard,
      ),
      _FeatureShortcut(
          'Settings', Icons.settings_rounded, widget.onOpenSettings),
    ];

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        final scheme = Theme.of(context).colorScheme;
        final panelWidth = MediaQuery.of(context).size.width * 0.74;
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: panelWidth.clamp(260.0, 360.0),
              height: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(4, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Features',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: features.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = features[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).pop();
                                item.onTap();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.32),
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: scheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    Icon(item.icon,
                                        color: scheme.primary, size: 19),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final headlineSize = width < 380 ? 30.0 : 34.0;
    final greeting = _timeGreeting();

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF11151B),
                    Color(0xFF0D1117),
                    Color(0xFF0B0F14),
                  ]
                : [
                    scheme.surface,
                    scheme.primaryContainer.withValues(alpha: 0.40),
                    scheme.surface,
                  ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 88),
          children: [
            Row(
              children: [
                Material(
                  color: isDark
                      ? const Color(0xFF1F2530)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showFeaturesMenu,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(
                        Icons.menu_rounded,
                        color:
                            isDark ? const Color(0xFFE6EAF2) : scheme.primary,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.circle,
                  color: isDark ? const Color(0xFF48A7FF) : scheme.primary,
                  size: 9,
                ),
                const SizedBox(width: 8),
                Text(
                  'Online',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFD4DBE6)
                        : scheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark
                      ? const Color(0xFF1F2530)
                      : scheme.surfaceContainerHighest,
                  backgroundImage:
                      _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null
                      ? Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '$greeting, $_name',
              style: TextStyle(
                color: isDark ? const Color(0xFFC9D0DB) : scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How can I help you today?',
              style: TextStyle(
                color: isDark ? const Color(0xFFEAF0F8) : scheme.onSurface,
                height: 1.1,
                fontSize: headlineSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HomeCard(
                    title: 'Chat with\nSINOVATE',
                    subtitle: 'Your AI study assistant',
                    icon: Icons.graphic_eq_rounded,
                    gradient: isDark
                        ? const [Color(0xFF1A2535), Color(0xFF17202E)]
                        : [
                            scheme.primary.withValues(alpha: 0.26),
                            scheme.secondary.withValues(alpha: 0.20),
                          ],
                    height: 210,
                    onTap: widget.onOpenNova,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _HomeCard(
                        title: 'Upcoming\nTests (10d)',
                        subtitle: _upcomingExamCount == 0
                            ? 'No tests in next 10 days'
                            : '$_upcomingExamCount in next 10 days',
                        icon: Icons.calendar_month_rounded,
                        gradient: isDark
                            ? const [Color(0xFF1F3550), Color(0xFF1A2D45)]
                            : [
                            scheme.tertiary.withValues(alpha: 0.26),
                            scheme.primary.withValues(alpha: 0.18),
                              ],
                        height: 100,
                        compact: true,
                        onTap: widget.onOpenExamsHub,
                      ),
                      const SizedBox(height: 10),
                      _HomeCard(
                        title: 'Login Streak',
                        subtitle: _loginStreakDays > 0
                            ? '$_loginStreakDays day streak'
                            : 'Start your streak today',
                        icon: Icons.local_fire_department_rounded,
                        gradient: isDark
                            ? const [Color(0xFF2A3140), Color(0xFF232A37)]
                            : [
                            scheme.secondary.withValues(alpha: 0.24),
                            scheme.tertiary.withValues(alpha: 0.15),
                              ],
                        height: 100,
                        compact: true,
                        onTap: null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE1E7EF) : scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onOpenNova,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFAAB4C2)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_recentChatWindows.isEmpty)
              const _HistoryEmptyCard()
            else
              ..._recentChatWindows.map(
                (chat) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChatHistoryCard(
                    title: chat.title,
                    subtitle: chat.subtitle,
                    timeText: _formatChatTime(chat.createdAt),
                    messagesText: '${chat.messageCount} messages',
                    onTap: widget.onOpenNova,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureShortcut {
  const _FeatureShortcut(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ChatWindowPreview {
  const _ChatWindowPreview({
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.messageCount,
  });

  final String title;
  final String subtitle;
  final DateTime createdAt;
  final int messageCount;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.height,
    this.compact = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final double height;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF0F4FA) : scheme.onSurface;
    final subtitleColor =
        isDark ? const Color(0xFFB6C1D2) : scheme.onSurfaceVariant;
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.82);
    final iconColor = isDark ? Colors.white : scheme.primary;
    final arrowColor = isDark ? const Color(0xFFE0E8F6) : scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outline.withValues(alpha: 0.20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: compact ? 16 : 20,
                    backgroundColor: iconBgColor,
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: compact ? 18 : 22,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.north_east_rounded,
                      color: arrowColor,
                      size: compact ? 22 : 26,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: compact ? 14 : 22,
                  height: compact ? 1.05 : 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                subtitle,
                maxLines: compact ? 2 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: compact ? 11.5 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHistoryCard extends StatelessWidget {
  const _ChatHistoryCard({
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.messagesText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String timeText;
  final String messagesText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(Icons.chat_outlined, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    messagesText,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No chat history yet. Start your first conversation with SINOVATE.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHostPage extends StatelessWidget {
  const _FeatureHostPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}
