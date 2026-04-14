import 'package:flutter/material.dart';

import '../models/learning_journey_record.dart';
import '../services/local_store_service.dart';
import 'learning_journey_screen.dart';

class LearningJourneyLibraryScreen extends StatefulWidget {
  const LearningJourneyLibraryScreen({
    super.key,
    required this.storeService,
  });

  final LocalStoreService storeService;

  @override
  State<LearningJourneyLibraryScreen> createState() =>
      _LearningJourneyLibraryScreenState();
}

class _LearningJourneyLibraryScreenState
    extends State<LearningJourneyLibraryScreen> {
  List<LearningJourneyRecord> _journeys = <LearningJourneyRecord>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final journeys = await widget.storeService.loadLearningJourneys();
    if (!mounted) {
      return;
    }
    setState(() {
      _journeys = journeys;
      _loading = false;
    });
  }

  String _subjectLabel(String key) {
    switch (key) {
      case 'physics':
        return 'Physics';
      case 'chemistry':
        return 'Chemistry';
      case 'maths':
        return 'Maths';
      case 'biology':
        return 'Biology';
      case 'optional':
        return 'Optional';
      default:
        return 'Journey';
    }
  }

  ({int completed, int total}) _journeyProgress(LearningJourneyRecord record) {
    final state = record.state;
    final subject = (state['subject'] ?? record.subject).toString();
    final completed =
        (state['completedTaskIds'] as List<dynamic>? ?? const <dynamic>[])
            .length;
    final savedTotal = int.tryParse((state['totalTasks'] ?? '').toString());
    if (savedTotal != null && savedTotal > 0) {
      return (completed: completed, total: savedTotal);
    }

    final optionalTasks =
        (state['optionalTasks'] as List<dynamic>? ?? const <dynamic>[]).length;
    final other = state['otherTasksBySubject'] as Map<String, dynamic>?;
    final fallbackTotal = subject == 'optional'
        ? optionalTasks
        : completed +
            ((other?[subject] as List<dynamic>?) ?? const <dynamic>[]).length;
    final total = fallbackTotal < completed ? completed : fallbackTotal;
    return (completed: completed, total: total);
  }

  Future<void> _openJourney(
      {String? journeyId, bool startFresh = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Learning Journey')),
          body: LearningJourneyScreen(
            storeService: widget.storeService,
            journeyId: journeyId,
            startFresh: startFresh,
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _deleteJourney(LearningJourneyRecord record) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Journey'),
          content: Text('Delete "${record.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await widget.storeService.deleteLearningJourney(record.id);
    if (!mounted) {
      return;
    }
    await _load();
  }

  String _subtitleForRecord(LearningJourneyRecord record) {
    final progress = _journeyProgress(record);
    final subject = _subjectLabel(record.subject);
    final examName = record.examName.trim();
    final examLabel = examName.isEmpty ? subject : examName;
    return '$examLabel • ${progress.completed}/${progress.total} tasks';
  }

  Color _subjectColor(String key, ThemeData theme) {
    switch (key) {
      case 'physics':
        return const Color(0xFF1E5FA8);
      case 'chemistry':
        return const Color(0xFF9E4D2C);
      case 'maths':
        return const Color(0xFF4A49A7);
      case 'biology':
        return const Color(0xFF2F6E26);
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _journeys.isEmpty ? null : _journeys.first;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: _loading ? null : () => _openJourney(startFresh: true),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? theme.colorScheme.surfaceContainerHigh
                          : theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.55),
                      isDark
                          ? theme.colorScheme.surface
                          : theme.colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDark
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: theme.colorScheme.primaryContainer,
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learning Journey',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saved journeys, progress snapshots, and new journey starts.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          latest == null ? Icons.add_rounded : Icons.play_arrow,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              latest?.title ?? 'No saved journey yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              latest == null
                                  ? 'Tap + to create your first journey.'
                                  : _subtitleForRecord(latest),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: latest == null
                            ? () => _openJourney(startFresh: true)
                            : () => _openJourney(journeyId: latest.id),
                        child: Text(latest == null ? 'New' : 'Resume'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_journeys.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No journeys saved yet.'),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _journeys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = _journeys[index];
                      final progress = _journeyProgress(record);
                      final subject = _subjectLabel(record.subject);
                      final examName = record.examName.trim();
                      final displayName = examName.isEmpty
                          ? (record.title.trim().isEmpty
                              ? subject
                              : record.title.trim())
                          : examName;
                      final subjectColor = _subjectColor(record.subject, theme);
                      final progressValue = progress.total == 0
                          ? 0.0
                          : progress.completed / progress.total;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openJourney(journeyId: record.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                Color.alphaBlend(
                                  subjectColor.withValues(alpha: 0.18),
                                  theme.colorScheme.surface,
                                ),
                                theme.colorScheme.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Color.alphaBlend(
                                subjectColor.withValues(alpha: 0.4),
                                theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    subjectColor.withValues(alpha: 0.18),
                                child: Text(
                                  subject.substring(0, 1),
                                  style: TextStyle(
                                    color: subjectColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subject,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: progressValue,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(20),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        subjectColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${progress.completed}/${progress.total} tasks • ${(progressValue * 100).round()}%',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteJourney(record),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
