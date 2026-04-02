import 'package:flutter/material.dart';

import '../services/local_store_service.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'collab_screen.dart';
import 'mind_map_landscape_screen.dart';
import 'notes_screen.dart';
import 'learning_journey_screen.dart';
import 'results_leaderboard_screen.dart';
import 'study_planner_screen.dart';
import 'tests_screen.dart';
import 'worksheet_screen.dart';

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
  int _index = 0;

  final LocalStoreService _storeService = LocalStoreService();

  static const List<String> _titles = <String>[
    'AI Tutor',
    'Learning Journey',
    'Notes',
    'More Tools',
  ];

  late final List<Widget> _pages = <Widget>[
    const ChatScreen(),
    LearningJourneyScreen(storeService: _storeService),
    NotesScreen(storeService: _storeService),
    _MoreHub(storeService: _storeService),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _DecorativeBackground(),
          SafeArea(
            top: false,
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (idx) => setState(() => _index = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined), label: 'Tutor'),
          NavigationDestination(
              icon: Icon(Icons.flag_circle_outlined), label: 'Journey'),
          NavigationDestination(
              icon: Icon(Icons.sticky_note_2_outlined), label: 'Notes'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class _DecorativeBackground extends StatelessWidget {
  const _DecorativeBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0B0F19), Color(0xFF121B2A)]
              : const [Color(0xFFF4F7FE), Color(0xFFEFF4FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowCircle(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _GlowCircle(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.13),
              size: 260,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _MoreHub extends StatelessWidget {
  const _MoreHub({required this.storeService});

  final LocalStoreService storeService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Everything else, neatly organized.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.hub_outlined,
          title: 'Mind Map Studio',
          subtitle: 'Landscape mind map canvas with central-topic branching.',
          onTap: () => _push(
            context,
            'Mind Map Studio',
            MindMapLandscapeScreen(storeService: storeService),
          ),
        ),
        _FeatureCard(
          icon: Icons.analytics_outlined,
          title: 'Tests',
          subtitle: 'Track marks and performance trends.',
          onTap: () =>
              _push(context, 'Tests', TestsScreen(storeService: storeService)),
        ),
        _FeatureCard(
          icon: Icons.calendar_month_outlined,
          title: 'Calendar',
          subtitle: 'See upcoming deadlines and study plans.',
          onTap: () => _push(
              context, 'Calendar', CalendarScreen(storeService: storeService)),
        ),
        _FeatureCard(
          icon: Icons.description_outlined,
          title: 'Worksheets',
          subtitle: 'Store and revisit worksheet files quickly.',
          onTap: () => _push(context, 'Worksheets',
              WorksheetScreen(storeService: storeService)),
        ),
        _FeatureCard(
          icon: Icons.timer_outlined,
          title: 'Countdown & Focus',
          subtitle: 'Exam countdown with daily reminders and focus timer.',
          onTap: () => _push(context, 'Countdown & Focus',
              StudyPlannerScreen(storeService: storeService)),
        ),
        _FeatureCard(
          icon: Icons.groups_2_outlined,
          title: 'Collab Hub',
          subtitle: 'Google sign-in, group chat, sharing, and Meet links.',
          onTap: () => _push(
              context, 'Collab Hub', CollabScreen(storeService: storeService)),
        ),
        _FeatureCard(
          icon: Icons.leaderboard_outlined,
          title: 'Results Leaderboard',
          subtitle:
              'Share test percentages and view subject-wise student rankings.',
          onTap: () => _push(
            context,
            'Results Leaderboard',
            ResultsLeaderboardScreen(storeService: storeService),
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FeatureHostPage(title: title, child: child),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
      body: Stack(
        children: [
          const _DecorativeBackground(),
          SafeArea(top: false, child: child),
        ],
      ),
    );
  }
}
