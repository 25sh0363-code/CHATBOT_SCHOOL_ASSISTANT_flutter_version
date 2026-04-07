import 'package:flutter/material.dart';

import '../services/local_store_service.dart';
import 'study_planner_screen.dart';
import 'tests_screen.dart';

class ExamsHubScreen extends StatefulWidget {
  const ExamsHubScreen({
    super.key,
    required this.storeService,
  });

  final LocalStoreService storeService;

  @override
  State<ExamsHubScreen> createState() => _ExamsHubScreenState();
}

class _ExamsHubScreenState extends State<ExamsHubScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exams Hub',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tests, scores, and countdown planning in one place.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        icon: Icon(Icons.analytics_outlined),
                        label: Text('Tests'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: Icon(Icons.timer_outlined),
                        label: Text('Countdown'),
                      ),
                    ],
                    selected: {_tabIndex},
                    onSelectionChanged: (selection) {
                      setState(() => _tabIndex = selection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              TestsScreen(storeService: widget.storeService),
              StudyPlannerScreen(
                storeService: widget.storeService,
                showExamCountdown: true,
                showFocusTimer: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
