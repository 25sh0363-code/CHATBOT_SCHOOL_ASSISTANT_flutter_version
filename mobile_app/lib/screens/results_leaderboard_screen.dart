import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/shared_test_result.dart';
import '../services/leaderboard_api_service.dart';
import '../services/local_store_service.dart';

class ResultsLeaderboardScreen extends StatefulWidget {
  const ResultsLeaderboardScreen({
    super.key,
    required this.storeService,
  });

  final LocalStoreService storeService;

  @override
  State<ResultsLeaderboardScreen> createState() =>
      _ResultsLeaderboardScreenState();
}

class _ResultsLeaderboardScreenState extends State<ResultsLeaderboardScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _testTitleController = TextEditingController();
  final TextEditingController _percentageController = TextEditingController();

  late final LeaderboardApiService _apiService = LeaderboardApiService(
    baseUrl: AppConfig.leaderboardAppsScriptUrl,
  );

  final List<String> _subjects = ['Physics', 'Chemistry', 'Math', 'Biology'];

  List<SharedTestResult> _results = <SharedTestResult>[];
  List<LeaderboardEntry> _remoteLeaderboard = <LeaderboardEntry>[];
  String? _remoteLeaderboardSubject;
  String _selectedSubject = 'Physics';
  String _viewSubject = 'Physics';
  bool _isSyncing = false;
  String? _statusMessage;
  final Set<String> _pendingCloudSyncKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _testTitleController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await widget.storeService.loadSharedTestResults();
    if (!mounted) {
      return;
    }
    setState(() {
      _results = data;
    });

    if (_apiService.isConfigured) {
      await _syncFromCloud();
    } else {
      setState(() {
        _statusMessage =
            'Cloud sync not configured. Using on-device leaderboard only.';
      });
    }
  }

  Future<void> _save() async {
    await widget.storeService.saveSharedTestResults(_results);
  }

  Future<bool> _confirmResultSubmission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submit result?'),
          content: const Text(
            'Leaderboard results are transparent. If false results are posted, fellow peers are free to report and take them down.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _addResult() async {
    final name = _nameController.text.trim();
    final percentage = double.tryParse(_percentageController.text.trim());
    final testTitle = _testTitleController.text.trim();

    if (name.isEmpty || percentage == null) {
      return;
    }

    final confirmed = await _confirmResultSubmission();
    if (!confirmed) {
      return;
    }

    final bounded = percentage.clamp(0, 100).toDouble();
    final result = SharedTestResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      studentName: name,
      subject: _selectedSubject,
      percentage: bounded,
      createdAt: DateTime.now(),
      testTitle: testTitle.isEmpty ? null : testTitle,
    );

    setState(() {
      _results.insert(0, result);
      _pendingCloudSyncKeys.add(_apiService.buildResultSyncKey(result));
      _viewSubject = _selectedSubject;
      _statusMessage = _apiService.isConfigured
          ? 'Result saved locally. Syncing to cloud...'
          : 'Result saved locally.';
    });
    await _save();

    if (_apiService.isConfigured) {
      try {
        await _apiService.submitResult(result);
        if (mounted) {
          setState(() {
            _statusMessage = 'Result synced to cloud.';
          });
        }
        await _syncFromCloud();
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'Saved locally, but cloud submit failed. ${e.toString()}';
          });
        }
      }
    }

    _testTitleController.clear();
    _percentageController.clear();
  }

  Future<void> _deleteResult(SharedTestResult item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete shared result?'),
          content: Text(
            'Remove ${item.studentName} - ${item.subject} (${item.percentage.toStringAsFixed(1)}%)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final previous = List<SharedTestResult>.from(_results);
    setState(() {
      _results.removeWhere((entry) => entry.id == item.id);
      _statusMessage = 'Deleting result...';
    });
    await _save();

    if (!_apiService.isConfigured) {
      setState(() {
        _statusMessage = 'Deleted from local leaderboard.';
      });
      return;
    }

    try {
      await _apiService.deleteResult(item);
      await _syncFromCloud();
      if (mounted) {
        setState(() {
          _statusMessage = 'Deleted from cloud leaderboard.';
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = previous;
        _statusMessage =
            'Delete failed on cloud backend. ${e.toString()}';
      });
      await _save();
    }
  }

  Future<void> _syncFromCloud() async {
    if (!_apiService.isConfigured) {
      return;
    }
    setState(() {
      _isSyncing = true;
    });

    try {
      final recent = await _apiService.fetchRecentResults(limit: 120);
      final leaderboard = await _apiService.fetchLeaderboard(
        subject: _viewSubject,
        limit: 120,
      );
      final mergedRecent = _mergePendingLocalResults(recent);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = mergedRecent;
        _remoteLeaderboard = leaderboard;
        _remoteLeaderboardSubject = _viewSubject;
        _reconcilePendingKeys(mergedRecent);
        _statusMessage =
            'Live cloud leaderboard active via Google Sheets backend.';
      });
      await _save();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Could not sync cloud leaderboard. Showing local cached data. ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  List<SharedTestResult> _mergePendingLocalResults(
      List<SharedTestResult> remoteRecent) {
    if (_pendingCloudSyncKeys.isEmpty) {
      return remoteRecent;
    }

    final remoteKeys =
        remoteRecent.map((item) => _apiService.buildResultSyncKey(item)).toSet();
    final pendingLocal = _results.where((item) {
      final key = _apiService.buildResultSyncKey(item);
      return _pendingCloudSyncKeys.contains(key) && !remoteKeys.contains(key);
    });

    return <SharedTestResult>[
      ...pendingLocal,
      ...remoteRecent,
    ];
  }

  void _reconcilePendingKeys(List<SharedTestResult> mergedRecent) {
    if (_pendingCloudSyncKeys.isEmpty) {
      return;
    }
    final syncedKeys =
        mergedRecent.map((item) => _apiService.buildResultSyncKey(item)).toSet();
    _pendingCloudSyncKeys.removeWhere((key) => syncedKeys.contains(key));
  }

  Future<void> _onViewSubjectChanged(String subject) async {
    setState(() {
      _viewSubject = subject;
      _remoteLeaderboard = <LeaderboardEntry>[];
      _remoteLeaderboardSubject = subject;
      _statusMessage = _apiService.isConfigured
          ? 'Refreshing $subject leaderboard...'
          : _statusMessage;
    });
    if (!_apiService.isConfigured) {
      return;
    }

    try {
      final leaderboard = await _apiService.fetchLeaderboard(
        subject: subject,
        limit: 120,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteLeaderboard = leaderboard;
        _remoteLeaderboardSubject = subject;
        _statusMessage = 'Showing latest $subject leaderboard.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteLeaderboardSubject = null;
        _statusMessage =
            'Could not refresh this subject from cloud. Showing cached/local ranking.';
      });
    }
  }

  List<LeaderboardEntry> _buildLocalLeaderboard(
      List<SharedTestResult> filtered) {
    final grouped = <String, List<SharedTestResult>>{};
    for (final item in filtered) {
      grouped
          .putIfAbsent(item.studentName, () => <SharedTestResult>[])
          .add(item);
    }

    final local = grouped.entries.map((entry) {
      final attempts = entry.value.length;
      final average = entry.value
              .map((e) => e.percentage)
              .fold<double>(0, (sum, v) => sum + v) /
          attempts;
      final lastUpdated = entry.value
          .map((e) => e.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return LeaderboardEntry(
        studentName: entry.key,
        subject: _viewSubject,
        attempts: attempts,
        averagePercentage: average,
        updatedAt: lastUpdated,
      );
    }).toList()
      ..sort((a, b) {
        final scoreSort = b.averagePercentage.compareTo(a.averagePercentage);
        if (scoreSort != 0) {
          return scoreSort;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return local;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _results.where((r) => r.subject == _viewSubject).toList();
    final hasRemoteForCurrent =
        _apiService.isConfigured && _remoteLeaderboardSubject == _viewSubject;
    final leaderboard = hasRemoteForCurrent
        ? _remoteLeaderboard
        : _buildLocalLeaderboard(filtered);
    final topScore = leaderboard.isEmpty
        ? 100.0
        : leaderboard.first.averagePercentage.clamp(1.0, 100.0);
    final topThree = leaderboard.take(3).toList();
    final rankedRest =
        leaderboard.length > 3 ? leaderboard.sublist(3) : <LeaderboardEntry>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share Test Result',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Student name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _testTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Test title (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubject,
                  items: _subjects
                      .map((subject) => DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubject = value ?? _selectedSubject;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _percentageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Percentage'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSyncing ? null : _addResult,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: Text(_isSyncing ? 'Please wait...' : 'Share Result'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leaderboard (Overall % by Subject)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Climb the ranks by improving your subject average.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSyncing
                        ? null
                        : () {
                            _syncFromCloud();
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(_isSyncing ? 'Syncing...' : 'Refresh'),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _subjects.map((subject) {
                      final selected = subject == _viewSubject;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text(subject),
                          onSelected: (_) {
                            _onViewSubjectChanged(subject);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                if (leaderboard.isEmpty)
                  const Text('No shared results for this subject yet.')
                else
                  Column(
                    children: [
                      _MotivationBanner(
                        subject: _viewSubject,
                        topScore: topScore,
                        participants: leaderboard.length,
                      ),
                      const SizedBox(height: 12),
                      if (topThree.isNotEmpty)
                        _PodiumSection(entries: topThree),
                      if (rankedRest.isNotEmpty) const SizedBox(height: 12),
                      for (var i = 0; i < rankedRest.length; i++)
                        _RankProgressTile(
                          rank: i + 4,
                          entry: rankedRest[i],
                          topScore: topScore,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Shared Results',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (_results.isEmpty)
                  const Text('No shared results yet.')
                else
                  Column(
                    children: _results.take(12).map((item) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.studentName),
                        subtitle: Text(
                          '${item.subject} | ${item.testTitle ?? 'Untitled test'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${item.percentage.toStringAsFixed(1)}%'),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed:
                                  _isSyncing ? null : () => _deleteResult(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  const _MotivationBanner({
    required this.subject,
    required this.topScore,
    required this.participants,
  });

  final String subject;
  final double topScore;
  final int participants;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.88),
            scheme.secondaryContainer.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$subject challenge: top score ${topScore.toStringAsFixed(1)}% across $participants students.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? first = entries.isNotEmpty ? entries[0] : null;
    LeaderboardEntry? second = entries.length > 1 ? entries[1] : null;
    LeaderboardEntry? third = entries.length > 2 ? entries[2] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumBlock(rank: 2, entry: second, height: 74)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumBlock(rank: 1, entry: first, height: 98)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumBlock(rank: 3, entry: third, height: 64)),
        ],
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.rank,
    required this.entry,
    required this.height,
  });

  final int rank;
  final LeaderboardEntry? entry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (entry == null) {
      return const SizedBox.shrink();
    }

    final icon = rank == 1
        ? Icons.emoji_events
        : rank == 2
            ? Icons.workspace_premium
            : Icons.military_tech;
    final color = rank == 1
        ? const Color(0xFFFFB300)
        : rank == 2
            ? const Color(0xFF90A4AE)
            : const Color(0xFFBF8A5A);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: rank == 1 ? 28 : 24),
        const SizedBox(height: 4),
        Text(
          entry!.studentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          '${entry!.averagePercentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}

class _RankProgressTile extends StatelessWidget {
  const _RankProgressTile({
    required this.rank,
    required this.entry,
    required this.topScore,
  });

  final int rank;
  final LeaderboardEntry entry;
  final double topScore;

  @override
  Widget build(BuildContext context) {
    final progress = (entry.averagePercentage / topScore).clamp(0.0, 1.0);
    final gap = math.max(0, topScore - entry.averagePercentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text('#$rank')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.studentName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Attempts ${entry.attempts} | ${entry.subject}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${entry.averagePercentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                gap == 0
                    ? 'At the top spot'
                    : '${gap.toStringAsFixed(1)}% to reach top',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
