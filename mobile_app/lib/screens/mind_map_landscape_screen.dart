import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/mind_map_record.dart';
import '../services/chat_api_service.dart';
import '../services/local_store_service.dart';

class MindMapLandscapeScreen extends StatefulWidget {
  const MindMapLandscapeScreen({
    super.key,
    required this.storeService,
  });

  final LocalStoreService storeService;

  @override
  State<MindMapLandscapeScreen> createState() => _MindMapLandscapeScreenState();
}

class _MindMapLandscapeScreenState extends State<MindMapLandscapeScreen> {
  final TextEditingController _topicController =
      TextEditingController(text: 'Physics');
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _contentController = TextEditingController(
    text:
        '# Classical Mechanics\n## Newton\'s Laws\n## Kinematics\n## Dynamics\n\n# Electromagnetism\n## Maxwell\'s Equations\n## Electric Fields\n\n# Thermodynamics\n## Laws of Thermodynamics\n## Heat Transfer\n\n# Relativity\n## Special Relativity\n## General Relativity\n\n# Quantum Mechanics\n## Wave-Particle Duality\n## Uncertainty Principle',
  );
  final ChatApiService _chatApiService =
      ChatApiService(baseUrl: AppConfig.backendBaseUrl);

  List<MindMapRecord> _mindMaps = <MindMapRecord>[];
  String? _selectedMindMapId;
  String _currentDrawingJson = '[]';
  bool _generatingMindMap = false;
  bool _canvasFullscreen = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _detailsController.dispose();
    _contentController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _saveMindMapNote({
    required String topic,
    required String content,
  }) async {
    final now = DateTime.now();
    final mindMap = MindMapRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: topic,
      topic: topic,
      content: content,
      drawingJson: '[]',
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _mindMaps.insert(0, mindMap);
      _selectedMindMapId = mindMap.id;
      _currentDrawingJson = mindMap.drawingJson;
    });
    await widget.storeService.saveMindMaps(_mindMaps);
  }

  Future<void> _showMindMapSavedDialog(String message) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mind map saved'),
          content: Text(message),
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

  Future<void> _generateAndSaveMindMap() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty || _generatingMindMap) {
      return;
    }

    setState(() {
      _generatingMindMap = true;
    });

    try {
      final mindMap = await _chatApiService.generateMindMap(
        topic: topic,
        details: _detailsController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      await _saveMindMapNote(topic: topic, content: mindMap);
      if (!mounted) {
        return;
      }

      setState(() {
        _contentController.text = mindMap;
      });

      await _showMindMapSavedDialog(
        'Mind map generated in studio and saved.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate mind map: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingMindMap = false;
        });
      }
    }
  }

  Future<void> _loadNotes() async {
    final notes = await widget.storeService.loadMindMaps();
    if (!mounted) {
      return;
    }
    setState(() {
      _mindMaps = notes;
    });
  }

  void _onSelectedMindMap(String? mindMapId) {
    if (mindMapId == null) {
      return;
    }
    final mindMap = _mindMaps.where((item) => item.id == mindMapId).firstOrNull;
    if (mindMap == null) {
      return;
    }
    setState(() {
      _selectedMindMapId = mindMapId;
      _topicController.text = mindMap.topic;
      _contentController.text = mindMap.content;
      _currentDrawingJson = mindMap.drawingJson;
    });
  }

  Future<void> _saveCurrentMindMap() async {
    final topic = _topicController.text.trim().isEmpty
        ? 'Mind Map'
        : _topicController.text.trim();
    final content = _contentController.text.trim();
    if (topic.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a topic first.')),
      );
      return;
    }

    final now = DateTime.now();
    final existingIndex = _selectedMindMapId == null
        ? -1
        : _mindMaps.indexWhere((item) => item.id == _selectedMindMapId);
    final mindMap = MindMapRecord(
      id: existingIndex >= 0
          ? _mindMaps[existingIndex].id
          : now.microsecondsSinceEpoch.toString(),
      title: topic,
      topic: topic,
      content: content,
      drawingJson: _currentDrawingJson,
      createdAt: existingIndex >= 0 ? _mindMaps[existingIndex].createdAt : now,
      updatedAt: now,
    );

    setState(() {
      if (existingIndex >= 0) {
        _mindMaps[existingIndex] = mindMap;
      } else {
        _mindMaps.insert(0, mindMap);
      }
      _selectedMindMapId = mindMap.id;
    });
    await widget.storeService.saveMindMaps(_mindMaps);
    await _showMindMapSavedDialog('Your mind map is saved.');
  }

  Future<void> _startMindMapFromScratch() async {
    setState(() {
      _topicController.text = 'Mind Map';
      _detailsController.clear();
      _contentController.clear();
      _selectedMindMapId = null;
      _currentDrawingJson = '[]';
    });
    await _saveCurrentMindMap();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Blank mind map created.')),
    );
  }

  Future<void> _deleteMindMap(String id) async {
    setState(() {
      _mindMaps.removeWhere((item) => item.id == id);
      if (_selectedMindMapId == id) {
        if (_mindMaps.isNotEmpty) {
          _selectedMindMapId = _mindMaps.first.id;
          _topicController.text = _mindMaps.first.topic;
          _contentController.text = _mindMaps.first.content;
          _currentDrawingJson = _mindMaps.first.drawingJson;
        } else {
          _selectedMindMapId = null;
          _currentDrawingJson = '[]';
        }
      }
    });
    await widget.storeService.saveMindMaps(_mindMaps);
  }

  String _formatDateTime(DateTime value) {
    final date = value.toIso8601String().split('T').first;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }

  List<_EditableBranch> _editableBranchesFromCurrentContent() {
    final parsed = _parseMindMap(
      _topicController.text.trim().isEmpty
          ? 'Mind Map'
          : _topicController.text.trim(),
      _contentController.text,
    );
    return parsed.branches.map(_editableBranchFromData).toList();
  }

  _EditableBranch _editableBranchFromData(_BranchData data) {
    return _EditableBranch(
      title: data.title,
      details: List<String>.from(data.details),
      children: data.children.map(_editableBranchFromData).toList(),
    );
  }

  String _serializeEditableBranches(List<_EditableBranch> branches) {
    if (branches.isEmpty) {
      return '';
    }

    final lines = <String>[];

    void writeBranch(_EditableBranch node, int level) {
      final headingLevel = math.max(1, level);
      lines.add('${'#' * headingLevel} ${node.title.trim()}');
      for (final detail in node.details) {
        final text = detail.trim();
        if (text.isNotEmpty) {
          lines.add('- $text');
        }
      }
      for (final child in node.children) {
        writeBranch(child, headingLevel + 1);
      }
    }

    for (final branch in branches) {
      writeBranch(branch, 1);
      lines.add('');
    }

    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }

    return lines.join('\n');
  }

  _EditableBranch _branchAtPath(List<_EditableBranch> roots, List<int> path) {
    _EditableBranch node = roots[path.first];
    for (var i = 1; i < path.length; i++) {
      node = node.children[path[i]];
    }
    return node;
  }

  Future<_BranchDraft?> _showBranchDraftDialog({
    required String title,
    String initialName = '',
    String initialDetails = '',
  }) async {
    final nameController = TextEditingController(text: initialName);
    final detailsController = TextEditingController(text: initialDetails);

    final result = await showDialog<_BranchDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Branch title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Branch content (one line per point)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              final details = detailsController.text
                  .split(RegExp(r'\r?\n'))
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList();
              Navigator.of(context).pop(
                _BranchDraft(
                  title: name,
                  details: details,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    detailsController.dispose();
    return result;
  }

  void _applyEditableBranches(List<_EditableBranch> roots) {
    setState(() {
      _contentController.text = _serializeEditableBranches(roots);
    });
  }

  Future<void> _addRootBranch() async {
    final draft = await _showBranchDraftDialog(title: 'Add root branch');
    if (draft == null) {
      return;
    }

    final roots = _editableBranchesFromCurrentContent();
    roots.add(
      _EditableBranch(
        title: draft.title,
        details: draft.details,
      ),
    );
    _applyEditableBranches(roots);
  }

  Future<void> _addChildBranch(List<int> parentPath) async {
    final draft = await _showBranchDraftDialog(title: 'Add child branch');
    if (draft == null) {
      return;
    }

    final roots = _editableBranchesFromCurrentContent();
    final parent = _branchAtPath(roots, parentPath);
    parent.children.add(
      _EditableBranch(
        title: draft.title,
        details: draft.details,
      ),
    );
    _applyEditableBranches(roots);
  }

  Future<void> _editBranch(List<int> path) async {
    final roots = _editableBranchesFromCurrentContent();
    final branch = _branchAtPath(roots, path);
    final draft = await _showBranchDraftDialog(
      title: 'Edit branch',
      initialName: branch.title,
      initialDetails: branch.details.join('\n'),
    );
    if (draft == null) {
      return;
    }

    branch.title = draft.title;
    branch.details
      ..clear()
      ..addAll(draft.details);
    _applyEditableBranches(roots);
  }

  Future<void> _deleteBranch(List<int> path) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete branch?'),
            content: const Text(
              'This removes the branch and its child branches.',
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
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    final roots = _editableBranchesFromCurrentContent();
    if (path.length == 1) {
      roots.removeAt(path.first);
    } else {
      final parent = _branchAtPath(roots, path.sublist(0, path.length - 1));
      parent.children.removeAt(path.last);
    }
    _applyEditableBranches(roots);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final mobileScreen = media.size.shortestSide < 700;
    final compactScreen = screenWidth < 1180;
    final map = _parseMindMap(
      _topicController.text.trim().isEmpty
          ? 'Mind Map'
          : _topicController.text.trim(),
      _contentController.text,
    );

    final showStudioPanel = !_canvasFullscreen && !compactScreen;

    return Padding(
      padding: _canvasFullscreen
          ? EdgeInsets.zero
          : EdgeInsets.all(mobileScreen ? 6 : 12),
      child: SizedBox.expand(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStudioPanel) ...[
              SizedBox(width: 330, child: _buildStudioPanel()),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _MindMapCanvas(
                      map: map,
                      drawingJson: _currentDrawingJson,
                      onDrawingJsonChanged: _updateCurrentDrawingJson,
                      fullscreen: false,
                      onToggleFullscreen: () {
                        _setCanvasFullscreen(true);
                      },
                      onAddRootBranch: _addRootBranch,
                    ),
                  ),
                  if (!_canvasFullscreen && !showStudioPanel)
                    Positioned(
                      left: mobileScreen ? 8 : 12,
                      top: mobileScreen ? 8 : 12,
                      child: FilledButton.icon(
                        onPressed: () => _showStudioSheet(context),
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(mobileScreen ? 'Edit' : 'Studio'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setCanvasFullscreen(bool enabled) async {
    if (!enabled) {
      if (!_canvasFullscreen) {
        return;
      }
      setState(() {
        _canvasFullscreen = false;
      });
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    if (_canvasFullscreen) {
      return;
    }

    setState(() {
      _canvasFullscreen = true;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) {
      return;
    }

    final map = _parseMindMap(
      _topicController.text.trim().isEmpty
          ? 'Mind Map'
          : _topicController.text.trim(),
      _contentController.text,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MindMapFullscreenPage(
          child: _MindMapCanvas(
            map: map,
            drawingJson: _currentDrawingJson,
            onDrawingJsonChanged: _updateCurrentDrawingJson,
            fullscreen: true,
            onToggleFullscreen: () => Navigator.of(context).maybePop(),
            onAddRootBranch: _addRootBranch,
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _canvasFullscreen = false;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Widget _buildStudioPanel() {
    final map = _parseMindMap(
      _topicController.text.trim().isEmpty
          ? 'Mind Map'
          : _topicController.text.trim(),
      _contentController.text,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Scrollbar(
          thumbVisibility: true,
          child: ListView(
            children: [
              Text(
                'Mind Map Studio',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Landscape map view inspired by your reference. Edit topic + markdown headings to shape branches.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(labelText: 'Center topic'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Chapter details/instructions (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _generatingMindMap ? null : _generateAndSaveMindMap,
                  icon: _generatingMindMap
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Generate & Save Mind Map'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saveCurrentMindMap,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Current Mind Map'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startMindMapFromScratch,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Start from Scratch'),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Saved Mind Maps',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (_mindMaps.isEmpty)
                Text(
                  'No saved mind maps yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mindMaps.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final mindMap = _mindMaps[index];
                    final isSelected = mindMap.id == _selectedMindMapId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _onSelectedMindMap(mindMap.id),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mindMap.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Delete mind map',
                                  onPressed: () => _deleteMindMap(mindMap.id),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mindMap.content,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.35),
                            ),
                            const Spacer(),
                            Text(
                              _formatDateTime(mindMap.updatedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              _buildBranchManagerCard(map),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Branch input (markdown headings)',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchManagerCard(_ParsedMindMap map) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Branch Editor',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _addRootBranch,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Root'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (map.branches.isEmpty)
            Text(
              'No branches yet. Add a root branch to start.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Column(
              children: map.branches
                  .asMap()
                  .entries
                  .map(
                    (entry) => _buildBranchEditorTile(
                      branch: entry.value,
                      path: [entry.key],
                      depth: 0,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchEditorTile({
    required _BranchData branch,
    required List<int> path,
    required int depth,
  }) {
    final indent = depth * 12.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Add child branch',
                  onPressed: () => _addChildBranch(path),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit branch',
                  onPressed: () => _editBranch(path),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete branch',
                  onPressed: () => _deleteBranch(path),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
            if (branch.details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                child: Text(
                  branch.details.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            if (branch.children.isNotEmpty)
              ...branch.children.asMap().entries.map(
                    (childEntry) => _buildBranchEditorTile(
                      branch: childEntry.value,
                      path: [...path, childEntry.key],
                      depth: depth + 1,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStudioSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildStudioPanel(),
        ),
      ),
    );
  }

  Future<void> _updateCurrentDrawingJson(String drawingJson) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentDrawingJson = drawingJson;
    });

    final selectedId = _selectedMindMapId;
    if (selectedId == null) {
      return;
    }

    final index = _mindMaps.indexWhere((item) => item.id == selectedId);
    if (index < 0) {
      return;
    }

    final updated = _mindMaps[index].copyWith(
      drawingJson: drawingJson,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _mindMaps[index] = updated;
    });
    await widget.storeService.saveMindMaps(_mindMaps);
  }
}

class _MindMapFullscreenPage extends StatelessWidget {
  const _MindMapFullscreenPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SizedBox.expand(child: child),
    );
  }
}

class _MindMapCanvas extends StatefulWidget {
  const _MindMapCanvas({
    required this.map,
    required this.drawingJson,
    required this.onDrawingJsonChanged,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.onAddRootBranch,
  });

  final _ParsedMindMap map;
  final String drawingJson;
  final ValueChanged<String> onDrawingJsonChanged;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final Future<void> Function() onAddRootBranch;

  static const List<Color> _palette = [
    Color(0xFFE57373),
    Color(0xFFFF7043),
    Color(0xFFEC407A),
    Color(0xFFE573D1),
    Color(0xFF7E57C2),
    Color(0xFF5C6BC0),
  ];

  @override
  State<_MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<_MindMapCanvas>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _exportBoundaryKey = GlobalKey();
  final List<_DrawStroke> _strokes = <_DrawStroke>[];
  final List<_DrawLabel> _labels = <_DrawLabel>[];
  final List<_DrawingSnapshot> _undoSnapshots = <_DrawingSnapshot>[];
  final List<_DrawingSnapshot> _redoSnapshots = <_DrawingSnapshot>[];
  bool _didInitialFit = false;
  String _lastLayoutFingerprint = '';
  Size? _lastViewportSize;
  bool _drawMode = false;
  bool _eraseMode = false;
  bool _eraseSessionRecorded = false;
  bool _textMode = false;
  bool _showDrawPalette = false;
  _DrawStroke? _activeStroke;
  Color _strokeColor = const Color(0xFF1565C0);
  double _strokeWidth = 3.2;
  double _textSize = 18;
  String? _lastCommittedDrawingJson;
  late final AnimationController _transformAnimationController;
  Animation<Matrix4>? _transformAnimation;

  static const List<Color> _drawColors = <Color>[
    Color(0xFF1565C0),
    Color(0xFFD32F2F),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFF000000),
  ];

  @override
  void initState() {
    super.initState();
    _transformAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    )..addListener(() {
        final animation = _transformAnimation;
        if (animation == null) {
          return;
        }
        _transformController.value = animation.value;
      });
    _loadDrawing(widget.drawingJson);
  }

  @override
  void didUpdateWidget(covariant _MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFingerprint = _fingerprintForMap(widget.map);
    if (nextFingerprint != _lastLayoutFingerprint) {
      _didInitialFit = false;
      _lastLayoutFingerprint = nextFingerprint;
    }

    if (oldWidget.drawingJson != widget.drawingJson) {
      if (_lastCommittedDrawingJson != null &&
          widget.drawingJson == _lastCommittedDrawingJson) {
        _lastCommittedDrawingJson = null;
      } else {
        _loadDrawing(widget.drawingJson);
      }
    }
  }

  @override
  void dispose() {
    _transformAnimationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _loadDrawing(String jsonText) {
    _strokes.clear();
    _labels.clear();
    _undoSnapshots.clear();
    _redoSnapshots.clear();
    _eraseSessionRecorded = false;
    _activeStroke = null;
    if (jsonText.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final stroke = _DrawStroke.fromJson(item);
            if (stroke.points.length >= 2) {
              _strokes.add(stroke);
            }
          }
        }
        return;
      }

      if (decoded is Map<String, dynamic>) {
        final rawStrokes =
            decoded['strokes'] as List<dynamic>? ?? const <dynamic>[];
        for (final item in rawStrokes) {
          if (item is Map<String, dynamic>) {
            final stroke = _DrawStroke.fromJson(item);
            if (stroke.points.length >= 2) {
              _strokes.add(stroke);
            }
          }
        }

        final rawLabels =
            decoded['labels'] as List<dynamic>? ?? const <dynamic>[];
        for (final item in rawLabels) {
          if (item is Map<String, dynamic>) {
            final label = _DrawLabel.fromJson(item);
            if (label.text.trim().isNotEmpty) {
              _labels.add(label);
            }
          }
        }
      }
    } catch (_) {
      // Ignore malformed saved drawing data.
    }
  }

  String _serializeDrawing() {
    return jsonEncode({
      'strokes': _strokes.map((stroke) => stroke.toJson()).toList(),
      'labels': _labels.map((label) => label.toJson()).toList(),
    });
  }

  void _commitDrawingChange() {
    final serialized = _serializeDrawing();
    _lastCommittedDrawingJson = serialized;
    widget.onDrawingJsonChanged(serialized);
  }

  _DrawingSnapshot _captureSnapshot() {
    return _DrawingSnapshot(
      strokes: _strokes.map(_copyStroke).toList(),
      labels: _labels.map(_copyLabel).toList(),
    );
  }

  _DrawStroke _copyStroke(_DrawStroke stroke) {
    return _DrawStroke(
      color: stroke.color,
      width: stroke.width,
      points: List<Offset>.from(stroke.points),
    );
  }

  _DrawLabel _copyLabel(_DrawLabel label) {
    return _DrawLabel(
      text: label.text,
      position: label.position,
      color: label.color,
      size: label.size,
    );
  }

  void _restoreSnapshot(_DrawingSnapshot snapshot) {
    _strokes
      ..clear()
      ..addAll(snapshot.strokes.map(_copyStroke));
    _labels
      ..clear()
      ..addAll(snapshot.labels.map(_copyLabel));
    _activeStroke = null;
    _eraseSessionRecorded = false;
  }

  void _recordHistorySnapshot() {
    _undoSnapshots.add(_captureSnapshot());
    _redoSnapshots.clear();
  }

  void _startStroke(Offset point) {
    if (_textMode) {
      return;
    }
    if (_eraseMode) {
      if (!_eraseSessionRecorded) {
        _recordHistorySnapshot();
        _eraseSessionRecorded = true;
      }
      _eraseAt(point);
      return;
    }

    setState(() {
      _recordHistorySnapshot();
      _activeStroke = _DrawStroke(
        color: _strokeColor,
        width: _strokeWidth,
        points: <Offset>[point],
      );
      _strokes.add(_activeStroke!);
    });
  }

  void _appendStrokePoint(Offset point) {
    if (_textMode) {
      return;
    }
    if (_eraseMode) {
      _eraseAt(point);
      return;
    }

    if (_activeStroke == null) {
      return;
    }
    setState(() {
      _activeStroke!.points.add(point);
    });
  }

  void _finishStroke() {
    if (_textMode) {
      return;
    }
    if (_eraseMode) {
      _eraseSessionRecorded = false;
      _commitDrawingChange();
      return;
    }

    if (_activeStroke == null) {
      return;
    }
    final stroke = _activeStroke!;
    _activeStroke = null;
    if (stroke.points.length < 2) {
      setState(() {
        _strokes.remove(stroke);
        if (_undoSnapshots.isNotEmpty) {
          _restoreSnapshot(_undoSnapshots.removeLast());
        }
      });
      return;
    }
    _commitDrawingChange();
  }

  void _undoChange() {
    if (_undoSnapshots.isEmpty) {
      return;
    }
    setState(() {
      _redoSnapshots.add(_captureSnapshot());
      _restoreSnapshot(_undoSnapshots.removeLast());
    });
    _commitDrawingChange();
  }

  void _redoChange() {
    if (_redoSnapshots.isEmpty) {
      return;
    }
    setState(() {
      _undoSnapshots.add(_captureSnapshot());
      _restoreSnapshot(_redoSnapshots.removeLast());
    });
    _commitDrawingChange();
  }

  void _clearStrokes() {
    if (_strokes.isEmpty && _labels.isEmpty) {
      return;
    }
    setState(() {
      _recordHistorySnapshot();
      _strokes.clear();
      _labels.clear();
      _activeStroke = null;
    });
    _commitDrawingChange();
  }

  void _eraseAt(Offset point) {
    final radius = (_strokeWidth * 3.2).clamp(10.0, 34.0);
    final beforeStrokes = _strokes.length;
    final beforeLabels = _labels.length;
    _strokes.removeWhere(
      (stroke) => stroke.points.any((p) => (p - point).distance <= radius),
    );
    _labels.removeWhere((label) => (label.position - point).distance <= radius);
    if (_strokes.length != beforeStrokes || _labels.length != beforeLabels) {
      setState(() {});
    }
  }

  Future<void> _addTextLabelAt(Offset point) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add text on canvas'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type text note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (text == null || text.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      _recordHistorySnapshot();
      _labels.add(
        _DrawLabel(
          text: text.trim(),
          position: point,
          color: _strokeColor,
          size: _textSize,
        ),
      );
    });
    _commitDrawingChange();
  }

  Future<void> _exportMindMapImage() async {
    try {
      final boundaryContext = _exportBoundaryKey.currentContext;
      if (boundaryContext == null) {
        return;
      }
      final boundary =
          boundaryContext.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }

      final image = await boundary.toImage(pixelRatio: 1.4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        return;
      }
      final bytes = data.buffer.asUint8List();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final safeTitle = widget.map.topic
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final suggestedName =
          '${safeTitle.isEmpty ? 'mind_map' : safeTitle}_$stamp.png';

      String outputPath;
      if (Platform.isMacOS) {
        final location = await getSaveLocation(
          suggestedName: suggestedName,
          acceptedTypeGroups: [
            const XTypeGroup(label: 'PNG Image', extensions: ['png']),
          ],
        );
        if (location == null || location.path.isEmpty) {
          return;
        }
        outputPath = location.path;
      } else {
        final dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        outputPath = '${dir.path}/$suggestedName';
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) {
        return;
      }

      if (Platform.isMacOS) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mind map exported to ${file.path}')),
        );
        return;
      }

      final openResult = await OpenFilex.open(file.path, type: 'image/png');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            openResult.type == ResultType.done
                ? 'Mind map exported: ${file.path}'
                : 'Mind map exported to ${file.path}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export image: $e')),
      );
    }
  }

  void _fitToViewport(
    BoxConstraints constraints,
    ui.Rect contentBounds,
  ) {
    final bounds = contentBounds.inflate(72);
    final scaleX = constraints.maxWidth / math.max(bounds.width, 1.0);
    final scaleY = constraints.maxHeight / math.max(bounds.height, 1.0);
    final scale = (math.min(scaleX, scaleY) * 0.94).clamp(0.12, 2.4);
    final dx = (constraints.maxWidth / 2) - (bounds.center.dx * scale);
    final dy = (constraints.maxHeight / 2) - (bounds.center.dy * scale);

    _animateTransformTo(
      Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1),
    );
  }

  void _animateTransformTo(Matrix4 target) {
    _transformAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _transformAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _transformAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  ui.Rect _contentBounds(List<_VisualNode> nodes) {
    if (nodes.isEmpty) {
      return const ui.Rect.fromLTWH(0, 0, 1, 1);
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final node in nodes) {
      final nodeLeft = node.center.dx - (node.width / 2);
      final nodeTop = node.center.dy - (node.height / 2);
      final nodeRight = node.center.dx + (node.width / 2);
      final nodeBottom = node.center.dy + (node.height / 2);
      left = math.min(left, nodeLeft);
      top = math.min(top, nodeTop);
      right = math.max(right, nodeRight);
      bottom = math.max(bottom, nodeBottom);
    }

    return ui.Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rootData = _BranchData(
          title: widget.map.topic,
          children: widget.map.branches,
        );
        final compactTools = constraints.maxWidth < 980;
        final tinyTools = constraints.maxWidth < 760;
        final phonePortrait = constraints.maxWidth < 760 &&
            constraints.maxHeight > constraints.maxWidth;

        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastViewportSize == null ||
            (_lastViewportSize!.width - viewportSize.width).abs() > 8 ||
            (_lastViewportSize!.height - viewportSize.height).abs() > 8) {
          _lastViewportSize = viewportSize;
          _didInitialFit = false;
        }

        var rawNodes = <_VisualNode>[];
        var rawEdges = <_VisualEdge>[];

        Color colorForDepth(int topIndex) {
          return _MindMapCanvas
              ._palette[topIndex % _MindMapCanvas._palette.length];
        }

        final canvasWidth = math.max(12000.0, constraints.maxWidth * 8.0);
        final canvasHeight = math.max(12000.0, constraints.maxHeight * 8.0);

        double nodeWidthForDepth(int depth) => depth == 0 ? 248.0 : 216.0;
        double nodeHeightForDepth(int depth) => depth == 0 ? 70.0 : 56.0;
        double horizontalGapForDepth(int depth) => depth == 0 ? 270.0 : 220.0;

        double subtreeSpan(_BranchData data, int depth) {
          final nodeHeight = nodeHeightForDepth(depth);
          if (data.children.isEmpty) {
            return nodeHeight;
          }

          const siblingGap = 26.0;
          final childSpans = data.children
              .map((child) => subtreeSpan(child, depth + 1))
              .toList();
          final totalChildrenSpan = childSpans.fold<double>(
                0,
                (sum, value) => sum + value,
              ) +
              siblingGap * (childSpans.length - 1);
          return math.max(nodeHeight, totalChildrenSpan);
        }

        void layoutNode({
          required _BranchData data,
          required int depth,
          required double xCenter,
          required double yCenter,
          required String id,
          required Color color,
          required double direction,
        }) {
          final width = nodeWidthForDepth(depth);
          final height = nodeHeightForDepth(depth);

          rawNodes.add(
            _VisualNode(
              id: id,
              label: data.title,
              details: _buildBranchDetailLines(data),
              center: Offset(xCenter, yCenter),
              width: width,
              height: height,
              color: const Color(0xFFEEF3FF),
              borderColor: color,
              textColor: const Color(0xFF172039),
            ),
          );

          if (data.children.isEmpty) {
            return;
          }

          final nextX = xCenter + (direction * horizontalGapForDepth(depth));
          final count = data.children.length;
          const siblingGap = 26.0;
          final childSpans = data.children
              .map((child) => subtreeSpan(child, depth + 1))
              .toList();
          final totalChildrenSpan = childSpans.fold<double>(
                0,
                (sum, value) => sum + value,
              ) +
              siblingGap * (count - 1);
          var cursorY = yCenter - (totalChildrenSpan / 2);

          for (var i = 0; i < count; i++) {
            final child = data.children[i];
            final childColor = depth == 0 ? colorForDepth(i) : color;
            final childSpan = childSpans[i];
            final childY = cursorY + (childSpan / 2);
            cursorY += childSpan + siblingGap;
            final childWidth = nodeWidthForDepth(depth + 1);

            rawEdges.add(
              _VisualEdge(
                from: Offset(xCenter + (direction * (width / 2)), yCenter),
                to: Offset(nextX - (direction * (childWidth / 2)), childY),
                color: childColor,
                bendLeft: direction < 0,
                thickness: depth == 1 ? 4.0 : 2.8,
              ),
            );

            layoutNode(
              data: child,
              depth: depth + 1,
              xCenter: nextX,
              yCenter: childY,
              id: '${id}_$i',
              color: childColor,
              direction: direction,
            );
          }
        }

        final rootCenter = Offset(canvasWidth / 2, canvasHeight / 2);
        final rootWidth = nodeWidthForDepth(0);
        final rootHeight = nodeHeightForDepth(0);

        rawNodes.add(
          _VisualNode(
            id: 'center',
            label: rootData.title,
            details: _buildBranchDetailLines(rootData),
            center: rootCenter,
            width: rootWidth,
            height: rootHeight,
            color: const Color(0xFF202548),
            borderColor: const Color(0xFF5663D4),
            textColor: Colors.white,
          ),
        );

        final rightIndices = <int>[];
        final leftIndices = <int>[];
        for (var i = 0; i < rootData.children.length; i++) {
          if (i.isEven) {
            rightIndices.add(i);
          } else {
            leftIndices.add(i);
          }
        }

        void layoutRootSide(List<int> indices, double direction) {
          if (indices.isEmpty) {
            return;
          }
          const siblingGap = 30.0;
          final spans = indices
              .map((index) => subtreeSpan(rootData.children[index], 1))
              .toList();
          final total = spans.fold<double>(0, (sum, value) => sum + value) +
              siblingGap * (spans.length - 1);
          var cursorY = rootCenter.dy - (total / 2);
          final childX = rootCenter.dx + (direction * horizontalGapForDepth(0));

          for (var i = 0; i < indices.length; i++) {
            final branchIndex = indices[i];
            final child = rootData.children[branchIndex];
            final childSpan = spans[i];
            final childY = cursorY + (childSpan / 2);
            cursorY += childSpan + siblingGap;
            final childWidth = nodeWidthForDepth(1);
            final color = colorForDepth(branchIndex);

            rawEdges.add(
              _VisualEdge(
                from: Offset(
                  rootCenter.dx + (direction * (rootWidth / 2)),
                  rootCenter.dy,
                ),
                to: Offset(
                  childX - (direction * (childWidth / 2)),
                  childY,
                ),
                color: color,
                bendLeft: direction < 0,
                thickness: 4.0,
              ),
            );

            layoutNode(
              data: child,
              depth: 1,
              xCenter: childX,
              yCenter: childY,
              id: 'center_$branchIndex',
              color: color,
              direction: direction,
            );
          }
        }

        layoutRootSide(rightIndices, 1);
        layoutRootSide(leftIndices, -1);

        final nodes = rawNodes;
        final edges = rawEdges;

        final contentBounds = _contentBounds(nodes);

        if (!_didInitialFit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _didInitialFit) {
              return;
            }
            _fitToViewport(constraints, contentBounds);
            _didInitialFit = true;
          });
        }

        return Card(
          margin: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: widget.fullscreen
                ? BorderRadius.zero
                : BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Color(0xFFF6F9FF),
                          Color(0xFFEAF0FF),
                          Color(0xFFE1EAFF),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: CustomPaint(
                    painter: _MindMapGridPainter(),
                  ),
                ),
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.12,
                    maxScale: 4.0,
                    panEnabled: !_drawMode,
                    scaleEnabled: !_drawMode,
                    constrained: false,
                    boundaryMargin: EdgeInsets.zero,
                    child: RepaintBoundary(
                      key: _exportBoundaryKey,
                      child: SizedBox(
                        width: canvasWidth,
                        height: canvasHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 1.15,
                                    colors: [
                                      Color(0xFFF6F9FF),
                                      Color(0xFFEAF0FF),
                                      Color(0xFFE1EAFF),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: _MindMapGridPainter(),
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _MindMapEdgePainter(edges: edges),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: _drawMode,
                              child: Stack(
                                children: nodes
                                    .map((node) =>
                                        _MindMapNodeWidget(node: node))
                                    .toList(),
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter:
                                    _MindMapDrawingPainter(strokes: _strokes),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: !_drawMode,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) =>
                                      _startStroke(details.localPosition),
                                  onPanUpdate: (details) =>
                                      _appendStrokePoint(details.localPosition),
                                  onPanEnd: (_) => _finishStroke(),
                                  onTapUp: (details) {
                                    if (_textMode) {
                                      _addTextLabelAt(details.localPosition);
                                    }
                                  },
                                ),
                              ),
                            ),
                            ..._labels.asMap().entries.map(
                                  (entry) => Positioned(
                                    left: entry.value.position.dx,
                                    top: entry.value.position.dy,
                                    child: GestureDetector(
                                      onPanStart: (_) {
                                        _recordHistorySnapshot();
                                      },
                                      onPanUpdate: (details) {
                                        final label = _labels[entry.key];
                                        setState(() {
                                          _labels[entry.key] = _DrawLabel(
                                            text: label.text,
                                            position:
                                                label.position + details.delta,
                                            color: label.color,
                                            size: label.size,
                                          );
                                        });
                                      },
                                      onPanEnd: (_) => _commitDrawingChange(),
                                      onDoubleTap: () {
                                        setState(() {
                                          _recordHistorySnapshot();
                                          _labels.removeAt(entry.key);
                                        });
                                        _commitDrawingChange();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.82),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: entry.value.color
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        child: Text(
                                          entry.value.text,
                                          style: TextStyle(
                                            color: entry.value.color,
                                            fontSize: entry.value.size,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
                if (phonePortrait)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF232746).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x50000000),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Text mode',
                              onPressed: () {
                                setState(() {
                                  _drawMode = true;
                                  _textMode = !_textMode;
                                  if (_textMode) {
                                    _eraseMode = false;
                                  }
                                  _showDrawPalette = true;
                                });
                              },
                              icon: Icon(
                                Icons.text_fields,
                                color: _textMode
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  _drawMode ? 'Disable draw' : 'Enable draw',
                              onPressed: () {
                                setState(() {
                                  _drawMode = !_drawMode;
                                  if (!_drawMode) {
                                    _eraseMode = false;
                                    _textMode = false;
                                    _showDrawPalette = false;
                                  } else {
                                    _showDrawPalette = true;
                                  }
                                });
                              },
                              icon: Icon(
                                _drawMode ? Icons.brush : Icons.brush_outlined,
                                color: _drawMode
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Palette',
                              onPressed: () {
                                setState(() {
                                  _drawMode = true;
                                  _showDrawPalette = !_showDrawPalette;
                                });
                              },
                              icon: const Icon(Icons.add),
                            ),
                            IconButton(
                              tooltip: 'Add root branch',
                              onPressed: () {
                                widget.onAddRootBranch();
                              },
                              icon: const Icon(
                                Icons.account_tree_outlined,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Undo',
                              onPressed: _undoChange,
                              icon: const Icon(Icons.undo, color: Colors.white),
                            ),
                            IconButton(
                              tooltip: 'Redo',
                              onPressed: _redoChange,
                              icon: const Icon(Icons.redo, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Material(
                          elevation: 2,
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  math.min(constraints.maxWidth - 20, 620),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: tinyTools ? 8 : 10,
                              vertical: tinyTools ? 6 : 8,
                            ),
                            child: Wrap(
                              spacing: tinyTools ? 4 : 8,
                              runSpacing: tinyTools ? 4 : 8,
                              alignment: WrapAlignment.end,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    setState(() {
                                      _drawMode = !_drawMode;
                                      if (!_drawMode) {
                                        _eraseMode = false;
                                        _textMode = false;
                                        _showDrawPalette = false;
                                      } else {
                                        _showDrawPalette = true;
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _drawMode
                                        ? Icons.edit_off_outlined
                                        : Icons.brush,
                                    size: 18,
                                  ),
                                  label: Text(_drawMode ? 'Done' : 'Draw'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => widget.onAddRootBranch(),
                                  icon: const Icon(
                                    Icons.account_tree_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Root +'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _undoChange,
                                  icon: const Icon(Icons.undo, size: 18),
                                  label: const Text('Undo'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _redoChange,
                                  icon: const Icon(Icons.redo, size: 18),
                                  label: const Text('Redo'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _clearStrokes,
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  label: const Text('Clear'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _exportMindMapImage,
                                  icon: const Icon(Icons.image_outlined,
                                      size: 18),
                                  label: const Text('PNG'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: widget.onToggleFullscreen,
                                  icon: Icon(
                                    widget.fullscreen
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    size: 18,
                                  ),
                                  label:
                                      Text(widget.fullscreen ? 'Exit' : 'Full'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _fitToViewport(
                                    constraints,
                                    contentBounds,
                                  ),
                                  icon: const Icon(
                                    Icons.center_focus_strong,
                                    size: 18,
                                  ),
                                  label: const Text('Center'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_drawMode && (!phonePortrait || _showDrawPalette))
                  Positioned(
                    right: 12,
                    bottom: phonePortrait ? 90 : 12,
                    child: Container(
                      width: math.min(430, constraints.maxWidth - 24),
                      constraints: BoxConstraints(
                        maxHeight: compactTools ? 250 : 340,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((compactTools || phonePortrait) &&
                                _showDrawPalette)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showDrawPalette = false;
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Hide'),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Pen'),
                                          selected: !_eraseMode && !_textMode,
                                          onSelected: (_) {
                                            setState(() {
                                              _eraseMode = false;
                                              _textMode = false;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Eraser'),
                                          selected: _eraseMode,
                                          onSelected: (_) {
                                            setState(() {
                                              _eraseMode = true;
                                              _textMode = false;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Text'),
                                          selected: _textMode,
                                          onSelected: (_) {
                                            setState(() {
                                              _textMode = true;
                                              _eraseMode = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _textMode
                                  ? 'Text mode: tap canvas to place text. Drag labels to move.'
                                  : _eraseMode
                                      ? 'Eraser mode active'
                                      : 'Pen mode active',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            if (!_eraseMode)
                              Wrap(
                                spacing: 8,
                                children: _drawColors.map((color) {
                                  final selected = _strokeColor == color;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _strokeColor = color);
                                    },
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Colors.white,
                                          width: selected ? 2.2 : 1.0,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _textMode
                                      ? 'Text size'
                                      : _eraseMode
                                          ? 'Eraser size'
                                          : 'Stroke thickness',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  (_textMode ? _textSize : _strokeWidth)
                                      .toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Slider(
                              value: _textMode ? _textSize : _strokeWidth,
                              min: _textMode ? 12 : 1.5,
                              max: _textMode ? 30 : 12,
                              divisions: _textMode ? 18 : 21,
                              label: (_textMode ? _textSize : _strokeWidth)
                                  .toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() {
                                  if (_textMode) {
                                    _textSize = value;
                                  } else {
                                    _strokeWidth = value;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MindMapNodeWidget extends StatelessWidget {
  const _MindMapNodeWidget({required this.node});

  final _VisualNode node;

  @override
  Widget build(BuildContext context) {
    final left = node.center.dx - node.width / 2;
    final top = node.center.dy - node.height / 2;
    final isCenter = node.id == 'center';
    final border = node.borderColor ?? node.color;

    return Positioned(
      left: left,
      top: top,
      width: node.width,
      height: node.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isCenter ? 26 : 18),
          onTap: () => _showNodeDetails(context, node),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: isCenter ? 16 : 12,
              vertical: isCenter ? 10 : 7,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCenter
                    ? const [Color(0xFF3948A8), Color(0xFF26306E)]
                    : [
                        Colors.white.withValues(alpha: 0.94),
                        node.color.withValues(alpha: 0.32),
                      ],
              ),
              borderRadius: BorderRadius.circular(isCenter ? 26 : 18),
              border: Border.all(color: border, width: isCenter ? 2.6 : 2.0),
              boxShadow: [
                BoxShadow(
                  color: border.withValues(alpha: isCenter ? 0.35 : 0.2),
                  blurRadius: isCenter ? 26 : 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              node.label,
              textAlign: TextAlign.center,
              maxLines: isCenter ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: node.textColor ?? const Color(0xFF333333),
                    fontWeight: isCenter ? FontWeight.w800 : FontWeight.w700,
                    height: 1.15,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MindMapGridPainter extends CustomPainter {
  const _MindMapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fine = Paint()
      ..color = const Color(0xFF8EA0CF).withValues(alpha: 0.11)
      ..strokeWidth = 1;
    const fineStep = 48.0;
    for (double x = 0; x <= size.width; x += fineStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fine);
    }
    for (double y = 0; y <= size.height; y += fineStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fine);
    }

    final major = Paint()
      ..color = const Color(0xFF6D81B8).withValues(alpha: 0.14)
      ..strokeWidth = 1.2;
    const majorStep = 240.0;
    for (double x = 0; x <= size.width; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = 0; y <= size.height; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapGridPainter oldDelegate) => false;
}

class _MindMapDrawingPainter extends CustomPainter {
  _MindMapDrawingPainter({required this.strokes});

  final List<_DrawStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) {
        continue;
      }

      final paint = Paint()
        ..color = stroke.color.withValues(alpha: 0.95)
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapDrawingPainter oldDelegate) {
    return true;
  }
}

Future<void> _showNodeDetails(BuildContext context, _VisualNode node) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              if (node.details.isEmpty)
                Text(
                  'No nested subheadings found for this topic.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: node.details.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return Text(
                        node.details[index],
                        style: Theme.of(context).textTheme.bodyLarge,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _MindMapEdgePainter extends CustomPainter {
  _MindMapEdgePainter({required this.edges});

  final List<_VisualEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final paint = Paint()
        ..color = edge.color.withValues(alpha: 0.92)
        ..strokeWidth = edge.thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(edge.from.dx, edge.from.dy);
      final dx = edge.to.dx - edge.from.dx;
      final controlOffset = dx.abs() * 0.42;
      final controlX1 =
          edge.from.dx + (dx >= 0 ? controlOffset : -controlOffset);
      final controlX2 = edge.to.dx - (dx >= 0 ? controlOffset : -controlOffset);
      path.cubicTo(
        controlX1,
        edge.from.dy,
        controlX2,
        edge.to.dy,
        edge.to.dx,
        edge.to.dy,
      );
      canvas.drawPath(path, paint);

      final glow = Paint()
        ..color = edge.color.withValues(alpha: 0.18)
        ..strokeWidth = edge.thickness + 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapEdgePainter oldDelegate) {
    return oldDelegate.edges != edges;
  }
}

class _ParsedMindMap {
  const _ParsedMindMap({
    required this.topic,
    required this.branches,
  });

  final String topic;
  final List<_BranchData> branches;
}

class _BranchData {
  const _BranchData({
    required this.title,
    this.details = const <String>[],
    this.children = const <_BranchData>[],
  });

  final String title;
  final List<String> details;
  final List<_BranchData> children;
}

class _VisualNode {
  const _VisualNode({
    required this.id,
    required this.label,
    required this.details,
    required this.center,
    required this.width,
    required this.height,
    required this.color,
    this.borderColor,
    this.textColor,
  });

  final String id;
  final String label;
  final List<String> details;
  final Offset center;
  final double width;
  final double height;
  final Color color;
  final Color? borderColor;
  final Color? textColor;
}

class _VisualEdge {
  const _VisualEdge({
    required this.from,
    required this.to,
    required this.color,
    required this.bendLeft,
    required this.thickness,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final bool bendLeft;
  final double thickness;
}

class _BranchDraft {
  const _BranchDraft({
    required this.title,
    required this.details,
  });

  final String title;
  final List<String> details;
}

class _EditableBranch {
  _EditableBranch({
    required this.title,
    this.details = const <String>[],
    this.children = const <_EditableBranch>[],
  });

  String title;
  final List<String> details;
  final List<_EditableBranch> children;
}

class _DrawStroke {
  _DrawStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;

  factory _DrawStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const <dynamic>[];
    final points = rawPoints
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => Offset(
            (item['x'] as num).toDouble(),
            (item['y'] as num).toDouble(),
          ),
        )
        .toList();

    return _DrawStroke(
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF1565C0),
      width: (json['width'] as num?)?.toDouble() ?? 3.2,
      points: points,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color.toARGB32(),
        'width': width,
        'points': points
            .map(
              (point) => {
                'x': point.dx,
                'y': point.dy,
              },
            )
            .toList(),
      };
}

class _DrawLabel {
  _DrawLabel({
    required this.text,
    required this.position,
    required this.color,
    required this.size,
  });

  final String text;
  final Offset position;
  final Color color;
  final double size;

  factory _DrawLabel.fromJson(Map<String, dynamic> json) {
    return _DrawLabel(
      text: (json['text'] ?? '') as String,
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF1565C0),
      size: (json['size'] as num?)?.toDouble() ?? 18,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'x': position.dx,
        'y': position.dy,
        'color': color.toARGB32(),
        'size': size,
      };
}

class _DrawingSnapshot {
  const _DrawingSnapshot({
    required this.strokes,
    required this.labels,
  });

  final List<_DrawStroke> strokes;
  final List<_DrawLabel> labels;
}

_ParsedMindMap _parseMindMap(String topic, String content) {
  final lines = content
      .split(RegExp(r'\r?\n'))
      .map(_InputLine.fromRaw)
      .where((line) => line.text.isNotEmpty)
      .toList();

  final headingPattern = RegExp(r'^(#{1,})\s+(.*)$');

  final branchEntries = <_BranchData>[];
  final headings = <({int level, String text})>[];

  for (final line in lines) {
    final match = headingPattern.firstMatch(line.text);
    if (match != null) {
      headings.add((
        level: match.group(1)!.length,
        text: _cleanNodeText(match.group(2)!),
      ));
    }
  }

  if (headings.isEmpty) {
    for (final line in lines.take(8)) {
      final title = _cleanNodeText(line.text);
      if (title.isNotEmpty) {
        branchEntries.add(_BranchData(title: title));
      }
    }
    if (branchEntries.isEmpty) {
      branchEntries.add(
        const _BranchData(
          title: 'Main Concept',
          children: [
            _BranchData(title: 'Subtopic'),
          ],
        ),
      );
    }
    return _ParsedMindMap(topic: topic, branches: branchEntries);
  }

  final rootNodes = <_TreeNode>[];
  final nodeStack = <_TreeNode>[];

  _TreeNode? activeTarget() => nodeStack.isEmpty ? null : nodeStack.last;

  for (final line in lines) {
    final headingMatch = headingPattern.firstMatch(line.text);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final text = _cleanNodeText(headingMatch.group(2)!);
      if (text.isEmpty) {
        continue;
      }

      while (nodeStack.isNotEmpty && nodeStack.last.level >= level) {
        nodeStack.removeLast();
      }

      final node = _TreeNode(level: level, title: text);
      if (nodeStack.isEmpty) {
        rootNodes.add(node);
      } else {
        nodeStack.last.children.add(node);
      }
      nodeStack.add(node);
      continue;
    }

    final target = activeTarget();
    if (target == null) {
      continue;
    }

    if (line.isTableRow) {
      final tableText = _tableRowToNodeTitle(line.text);
      if (tableText != null && tableText.isNotEmpty) {
        target.details.add(tableText);
      }
      continue;
    }

    final text = _cleanNodeText(line.text);
    if (text.isNotEmpty) {
      target.details.add(text);
    }
  }

  for (final node in rootNodes) {
    branchEntries.add(_branchFromTree(node));
  }

  if (branchEntries.isEmpty) {
    branchEntries.add(
      const _BranchData(
        title: 'Main Concept',
        children: [
          _BranchData(title: 'Subtopic'),
        ],
      ),
    );
  }

  return _ParsedMindMap(topic: topic, branches: branchEntries);
}

class _TreeNode {
  _TreeNode({
    required this.level,
    required this.title,
  });

  final int level;
  final String title;
  final List<String> details = <String>[];
  final List<_TreeNode> children = <_TreeNode>[];
}

class _InputLine {
  const _InputLine({
    required this.text,
    required this.isListItem,
    required this.isTableRow,
  });

  final String text;
  final bool isListItem;
  final bool isTableRow;

  static _InputLine fromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _InputLine(text: '', isListItem: false, isTableRow: false);
    }

    final listPattern = RegExp(r'^([-*+]|\d+[.)])\s+');
    final isList = listPattern.hasMatch(trimmed);
    var normalized = trimmed
        .replaceFirst(RegExp(r'^>+\s*'), '')
        .replaceFirst(listPattern, '')
        .trim();

    final isTableRow = _looksLikeMarkdownTableRow(normalized);

    // Convert list-prefixed headings like "- ## Coulomb's Law" into proper headings.
    final headingInsideList =
        RegExp(r'^(#{1,})\s+(.*)$').firstMatch(normalized);
    if (headingInsideList != null) {
      normalized =
          '${headingInsideList.group(1)!} ${headingInsideList.group(2)!.trim()}';
    }

    return _InputLine(
      text: normalized,
      isListItem: isList,
      isTableRow: isTableRow,
    );
  }
}

String _cleanNodeText(String input) {
  var value = input.trim();
  value = value.replaceAll(RegExp(r'[*_`]+'), '');
  value = value.replaceAll(RegExp(r'\s+'), ' ');
  value = value.replaceAll(RegExp(r'^[:\-–•\s]+'), '');
  value = value.replaceAll(RegExp(r'[:\-–\s]+$'), '');
  return value.trim();
}

_BranchData _branchFromTree(_TreeNode node) {
  return _BranchData(
    title: node.title,
    details: node.details,
    children: node.children.map(_branchFromTree).toList(),
  );
}

List<String> _buildBranchDetailLines(_BranchData branch, {int depth = 0}) {
  final lines = <String>[];
  final prefix = '${'  ' * depth}- ';
  lines.add('$prefix${branch.title}');
  final detailPrefix = '${'  ' * (depth + 1)}- ';
  for (final detail in branch.details) {
    lines.add('$detailPrefix$detail');
  }
  for (final child in branch.children) {
    lines.addAll(_buildBranchDetailLines(child, depth: depth + 1));
  }
  return lines;
}

String _fingerprintForMap(_ParsedMindMap map) {
  String walk(_BranchData node) {
    if (node.children.isEmpty) {
      return node.title;
    }
    return '${node.title}(${node.children.map(walk).join('|')})';
  }

  return '${map.topic}|${map.branches.map(walk).join('||')}';
}

bool _looksLikeMarkdownTableRow(String value) {
  if (!value.contains('|')) {
    return false;
  }
  final compact = value.replaceAll(' ', '');
  if (!compact.startsWith('|') || !compact.endsWith('|')) {
    return false;
  }
  final cells = compact.split('|').where((cell) => cell.isNotEmpty).toList();
  return cells.length >= 2;
}

String? _tableRowToNodeTitle(String row) {
  final rawCells = row.split('|').map((cell) => cell.trim()).toList();
  final cells = rawCells
      .where((cell) => cell.isNotEmpty)
      .map(_cleanNodeText)
      .where((cell) => cell.isNotEmpty)
      .toList();

  if (cells.isEmpty) {
    return null;
  }

  final isSeparator = cells.every(
    (cell) => RegExp(r'^:?-{2,}:?$').hasMatch(cell.replaceAll(' ', '')),
  );
  if (isSeparator) {
    return null;
  }

  return cells.join(' | ');
}
