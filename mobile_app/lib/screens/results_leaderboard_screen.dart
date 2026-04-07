import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

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
  final TextEditingController _testTitleController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _maxMarksController = TextEditingController();

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
  DateTime? _lastSyncAt;
  String _profileName = 'Student';
  String? _profilePhotoBase64;
  Uint8List? _profilePhotoBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _testTitleController.dispose();
    _scoreController.dispose();
    _maxMarksController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await widget.storeService.loadSharedTestResults();
    final profileName = await widget.storeService.loadProfileName();
    final profilePhotoBase64 = await widget.storeService.loadProfilePhotoBase64();
    Uint8List? profilePhotoBytes;
    if (profilePhotoBase64 != null && profilePhotoBase64.isNotEmpty) {
      try {
        profilePhotoBytes = base64Decode(profilePhotoBase64);
      } catch (_) {
        profilePhotoBytes = null;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _results = data;
      _profileName = profileName;
      _profilePhotoBase64 = profilePhotoBase64;
      _profilePhotoBytes = profilePhotoBytes;
    });

    if (_apiService.isConfigured) {
      await _syncFromCloud(force: true);
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

  Future<bool> _addResult() async {
    final score = double.tryParse(_scoreController.text.trim());
    final maxMarks = double.tryParse(_maxMarksController.text.trim());
    final testTitle = _testTitleController.text.trim();

    if (score == null || maxMarks == null || maxMarks <= 0) {
      return false;
    }

    final confirmed = await _confirmResultSubmission();
    if (!confirmed) {
      return false;
    }

    final bounded = score.clamp(0, maxMarks).toDouble();
    final result = SharedTestResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      studentName: _profileName,
      subject: _selectedSubject,
      score: bounded,
      maxMarks: maxMarks,
      createdAt: DateTime.now(),
      testTitle: testTitle.isEmpty ? null : testTitle,
      profilePhotoBase64: _profilePhotoBase64,
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

    if (mounted) {
      final message = _apiService.isConfigured
          ? 'Result added. Wait for cloud sync.'
          : 'Result added locally.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (_apiService.isConfigured) {
      _submitAndSyncInBackground(result);
    }

    _testTitleController.clear();
    _scoreController.clear();
    _maxMarksController.clear();
    return true;
  }

  Future<void> _submitAndSyncInBackground(SharedTestResult result) async {
    if (!_apiService.isConfigured) {
      return;
    }

    try {
      await _apiService.submitResult(result);
      if (mounted) {
        setState(() {
          _statusMessage = 'Result sent to cloud. Syncing latest leaderboard...';
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

  Future<void> _showResultQueuedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Result Added'),
          content: const Text(
            'Result sent to cloud. Please wait for it to sync.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddResultSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Result',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage:
                          _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null,
                      child: _profilePhotoBytes == null
                          ? Text(
                              _profileName.isEmpty
                                  ? 'S'
                                  : _profileName.substring(0, 1).toUpperCase(),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Posting as $_profileName',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
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
                      .map(
                        (subject) => DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject),
                        ),
                      )
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
                  controller: _scoreController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Marks scored'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _maxMarksController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(labelText: 'Out of (max marks)'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          final saved = await _addResult();
                          if (saved && mounted) {
                            Navigator.of(context).pop();
                            await _showResultQueuedDialog();
                          }
                        },
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(_isSyncing ? 'Please wait...' : 'Save result'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRecentResultsPopup() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 560,
            height: 480,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Recent Results',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _results.isEmpty
                        ? const Center(child: Text('No shared results yet.'))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.studentName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${item.subject} • ${item.testTitle ?? 'Untitled test'} • ${_formatMarks(item.score, item.maxMarks)}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${item.percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Delete',
                                      onPressed: _isSyncing
                                          ? null
                                          : () async {
                                              await _deleteResult(item);
                                              if (!context.mounted) {
                                                return;
                                              }
                                              Navigator.of(context).pop();
                                              if (mounted) {
                                                _showRecentResultsPopup();
                                              }
                                            },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteResult(SharedTestResult item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete shared result?'),
          content: Text(
            'Remove ${item.studentName} - ${item.subject} (${_formatMarks(item.score, item.maxMarks)})?',
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
        _statusMessage = 'Delete failed on cloud backend. ${e.toString()}';
      });
      await _save();
    }
  }

  Future<void> _syncFromCloud({bool force = false}) async {
    if (!_apiService.isConfigured) {
      return;
    }

    if (_isSyncing) {
      return;
    }

    if (!force && _lastSyncAt != null) {
      final elapsed = DateTime.now().difference(_lastSyncAt!);
      if (elapsed < const Duration(seconds: 5)) {
        return;
      }
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final bundle = await _apiService.fetchSyncBundle(
        subject: _viewSubject,
        recentLimit: 50,
        leaderboardLimit: 50,
      );
      final recent = bundle.recentResults;
      final leaderboard = bundle.leaderboard;
      final mergedRecent = _mergePendingLocalResults(recent);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = mergedRecent;
        _remoteLeaderboard = leaderboard;
        _remoteLeaderboardSubject = _viewSubject;
        _reconcilePendingKeys(mergedRecent);
        _lastSyncAt = DateTime.now();
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
    final merged = <SharedTestResult>[];
    final seenIds = <String>{};
    final seenKeys = <String>{};

    void addUnique(SharedTestResult item) {
      final id = item.id.trim();
      final key = _apiService.buildResultSyncKey(item);
      if (id.isNotEmpty && seenIds.contains(id)) {
        return;
      }
      if (seenKeys.contains(key)) {
        return;
      }
      if (id.isNotEmpty) {
        seenIds.add(id);
      }
      seenKeys.add(key);
      merged.add(item);
    }

    final remoteKeys = remoteRecent
        .map((item) => _apiService.buildResultSyncKey(item))
        .toSet();

    for (final item in _results) {
      final key = _apiService.buildResultSyncKey(item);
      if (_pendingCloudSyncKeys.contains(key) && !remoteKeys.contains(key)) {
        addUnique(item);
      }
    }
    for (final item in remoteRecent) {
      addUnique(item);
    }

    return merged;
  }

  void _reconcilePendingKeys(List<SharedTestResult> mergedRecent) {
    if (_pendingCloudSyncKeys.isEmpty) {
      return;
    }
    final syncedKeys = mergedRecent
        .map((item) => _apiService.buildResultSyncKey(item))
        .toSet();
    _pendingCloudSyncKeys.removeWhere((key) => syncedKeys.contains(key));
  }

  String _formatMarks(double score, double maxMarks) {
    final scoreDigits = score.truncateToDouble() == score ? 0 : 1;
    final maxDigits = maxMarks.truncateToDouble() == maxMarks ? 0 : 1;
    return '${score.toStringAsFixed(scoreDigits)}/${maxMarks.toStringAsFixed(maxDigits)}';
  }

  Uint8List? _decodeAvatar(String? base64Value) {
    if (base64Value == null || base64Value.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64Value);
    } catch (_) {
      return null;
    }
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
      final averageScore =
          entry.value.map((e) => e.score).fold<double>(0, (sum, v) => sum + v) /
              attempts;
      final averageMaxMarks = entry.value
              .map((e) => e.maxMarks)
              .fold<double>(0, (sum, v) => sum + v) /
          attempts;
        final averagePercentage = averageMaxMarks <= 0
          ? 0.0
          : (averageScore / averageMaxMarks) * 100;
      final lastUpdated = entry.value
          .map((e) => e.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final latestForPhoto = entry.value.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );
      return LeaderboardEntry(
        studentName: entry.key,
        subject: _viewSubject,
        attempts: attempts,
        averagePercentage: averagePercentage,
        averageScore: averageScore,
        averageMaxMarks: averageMaxMarks,
        profilePhotoBase64: latestForPhoto.profilePhotoBase64,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _results.where((r) => r.subject == _viewSubject).toList();
    final hasRemoteForCurrent =
        _apiService.isConfigured && _remoteLeaderboardSubject == _viewSubject;
    final leaderboard = hasRemoteForCurrent
        ? _remoteLeaderboard
        : _buildLocalLeaderboard(filtered);
    final topPercent = leaderboard.isEmpty
      ? 100.0
      : leaderboard.first.averagePercentage.clamp(1.0, 100.0).toDouble();
    final topThree = leaderboard.take(3).toList();
    final rankedRest =
        leaderboard.length > 3 ? leaderboard.sublist(3) : <LeaderboardEntry>[];

    final topEntry = leaderboard.isNotEmpty ? leaderboard.first : null;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 124),
          children: [
            Text(
              'Leaderboard',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  _statusMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: topEntry != null
                        ? (_decodeAvatar(topEntry.profilePhotoBase64) != null
                            ? MemoryImage(_decodeAvatar(topEntry.profilePhotoBase64)!)
                            : null)
                        : null,
                    child: topEntry == null
                        ? Text(
                            '🏆',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          )
                        : _decodeAvatar(topEntry.profilePhotoBase64) == null
                            ? Text(
                                topEntry.studentName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topEntry?.studentName ?? 'No topper yet',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 32 / 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (topEntry != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${topEntry.averagePercentage.toStringAsFixed(1)}% overall',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _viewSubject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    dropdownColor: scheme.surface,
                    items: _subjects
                        .map(
                          (subject) => DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          ),
                        )
                        .toList(),
                    onChanged: _isSyncing
                        ? null
                        : (value) {
                            if (value != null) {
                              _onViewSubjectChanged(value);
                            }
                          },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isSyncing
                          ? null
                          : () {
                              _syncFromCloud(force: true);
                            },
                      icon: const Icon(Icons.refresh),
                      label: Text(_isSyncing ? 'Syncing...' : 'Refresh'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Rankings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
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
                            topPercentage:
                                leaderboard.first.averagePercentage,
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
                              topPercent: topPercent,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'leaderboard_recent',
                onPressed: _isSyncing ? null : _showRecentResultsPopup,
                child: const Icon(Icons.history_rounded),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'leaderboard_add',
                onPressed: _isSyncing ? null : _showAddResultSheet,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  const _MotivationBanner({
    required this.subject,
    required this.topPercentage,
    required this.participants,
  });

  final String subject;
  final double topPercentage;
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
              '$subject challenge: top overall ${topPercentage.toStringAsFixed(1)}% across $participants students.',
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
        CircleAvatar(
          radius: rank == 1 ? 16 : 14,
          backgroundColor: color.withValues(alpha: 0.16),
          backgroundImage: _avatarBytes(entry!.profilePhotoBase64) != null
              ? MemoryImage(_avatarBytes(entry!.profilePhotoBase64)!)
              : null,
          child: _avatarBytes(entry!.profilePhotoBase64) == null
              ? Text(
                  entry!.studentName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
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

  Uint8List? _avatarBytes(String? base64Value) {
    if (base64Value == null || base64Value.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64Value);
    } catch (_) {
      return null;
    }
  }
}

class _RankProgressTile extends StatelessWidget {
  const _RankProgressTile({
    required this.rank,
    required this.entry,
    required this.topPercent,
  });

  final int rank;
  final LeaderboardEntry entry;
  final double topPercent;

  @override
  Widget build(BuildContext context) {
    final progress = (entry.averagePercentage / topPercent).clamp(0.0, 1.0);
    final gap = math.max(0, topPercent - entry.averagePercentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: _avatarBytes(entry.profilePhotoBase64) != null
                      ? MemoryImage(_avatarBytes(entry.profilePhotoBase64)!)
                      : null,
                  child: _avatarBytes(entry.profilePhotoBase64) == null
                      ? Text('#$rank')
                      : null,
                ),
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
                    : '${gap.toStringAsFixed(1)}% away from top ratio',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Uint8List? _avatarBytes(String? base64Value) {
    if (base64Value == null || base64Value.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64Value);
    } catch (_) {
      return null;
    }
  }
}
