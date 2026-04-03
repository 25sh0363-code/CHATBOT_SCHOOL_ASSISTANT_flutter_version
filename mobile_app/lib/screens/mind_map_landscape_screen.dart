import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/quick_note.dart';
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

  List<QuickNote> _notes = <QuickNote>[];
  String? _selectedNoteId;
  bool _generatingMindMap = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadNotes();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _detailsController.dispose();
    _contentController.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _saveMindMapNote({
    required String topic,
    required String content,
  }) async {
    final now = DateTime.now();
    final note = QuickNote(
      id: now.microsecondsSinceEpoch.toString(),
      topic: topic,
      content: content,
      createdAt: now,
      updatedAt: now,
      attachments: const <QuickNoteAttachment>[],
    );

    setState(() {
      _notes.insert(0, note);
      _selectedNoteId = note.id;
    });
    await widget.storeService.saveQuickNotes(_notes);
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mind map generated in studio and saved.')),
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
    final notes = await widget.storeService.loadQuickNotes();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
    });
  }

  void _onSelectedNote(String? noteId) {
    if (noteId == null) {
      return;
    }
    final note = _notes.where((item) => item.id == noteId).firstOrNull;
    if (note == null) {
      return;
    }
    setState(() {
      _selectedNoteId = noteId;
      _topicController.text = note.topic;
      _contentController.text = note.content;
    });
  }

  @override
  Widget build(BuildContext context) {
    final map = _parseMindMap(
      _topicController.text.trim().isEmpty
          ? 'Mind Map'
          : _topicController.text.trim(),
      _contentController.text,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 330,
            child: Card(
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedNoteId,
                        hint: const Text('Load from saved note'),
                        items: _notes
                            .map(
                              (note) => DropdownMenuItem<String>(
                                value: note.id,
                                child: Text(note.topic),
                              ),
                            )
                            .toList(),
                        onChanged: _onSelectedNote,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _topicController,
                        decoration:
                            const InputDecoration(labelText: 'Center topic'),
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
                          onPressed: _generatingMindMap
                              ? null
                              : _generateAndSaveMindMap,
                          icon: _generatingMindMap
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Generate & Save Mind Map'),
                        ),
                      ),
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
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MindMapCanvas(map: map),
          ),
        ],
      ),
    );
  }
}

class _MindMapCanvas extends StatefulWidget {
  const _MindMapCanvas({required this.map});

  final _ParsedMindMap map;

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

class _MindMapCanvasState extends State<_MindMapCanvas> {
  final TransformationController _transformController =
      TransformationController();
  bool _didInitialFit = false;
  String _lastLayoutFingerprint = '';

  @override
  void didUpdateWidget(covariant _MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFingerprint = _fingerprintForMap(widget.map);
    if (nextFingerprint != _lastLayoutFingerprint) {
      _didInitialFit = false;
      _lastLayoutFingerprint = nextFingerprint;
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _fitToViewport(
    BoxConstraints constraints,
    double canvasWidth,
    double canvasHeight,
  ) {
    final scaleX = constraints.maxWidth / canvasWidth;
    final scaleY = constraints.maxHeight / canvasHeight;
    final scale = (math.min(scaleX, scaleY) * 0.94).clamp(0.22, 2.4);
    final dx = (constraints.maxWidth - (canvasWidth * scale)) / 2;
    final dy = (constraints.maxHeight - (canvasHeight * scale)) / 2;

    _transformController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTreeDepth = _maxBranchDepth(widget.map.branches) + 1;
        final levelGap = 136.0;
        final topY = 94.0;

        double nodeWidthForDepth(int depth) {
          if (depth == 0) {
            return 230.0;
          }
          if (depth == 1) {
            return 240.0;
          }
          return math.max(188.0, 236.0 - ((depth - 1) * 14));
        }

        double minSpanForDepth(int depth) {
          return nodeWidthForDepth(depth) + 34;
        }

        final rootData = _BranchData(
          title: widget.map.topic,
          children: widget.map.branches,
        );

        double subtreeWidth(_BranchData data, int depth) {
          if (data.children.isEmpty) {
            return minSpanForDepth(depth);
          }

          final childrenSpan = data.children
              .map((child) => subtreeWidth(child, depth + 1))
              .fold<double>(0.0, (sum, span) => sum + span);
          return math.max(childrenSpan, minSpanForDepth(depth));
        }

        final requiredTreeWidth = subtreeWidth(rootData, 0);

        final canvasWidth = math.max(
          1500.0,
          math.max(
            constraints.maxWidth * 1.12,
            requiredTreeWidth + 300,
          ),
        );
        final canvasHeight = math.max(
          860.0,
          math.max(
            constraints.maxHeight * 1.15,
            (maxTreeDepth * levelGap) + 220,
          ),
        );

        if (!_didInitialFit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _didInitialFit) {
              return;
            }
            _fitToViewport(constraints, canvasWidth, canvasHeight);
            _didInitialFit = true;
          });
        }

        final rootCenter = Offset(canvasWidth / 2, topY);
        final nodes = <_VisualNode>[];
        final edges = <_VisualEdge>[];

        Color colorForDepth(int topIndex) {
          return _MindMapCanvas
              ._palette[topIndex % _MindMapCanvas._palette.length];
        }

        void layoutNode({
          required _BranchData data,
          required int depth,
          required double xCenter,
          required double xSpan,
          required String id,
          required Color color,
        }) {
          final y = topY + (depth * levelGap);
          final width = nodeWidthForDepth(depth);
          final height = depth <= 1 ? 58.0 : 52.0;
          final isRoot = depth == 0;

          nodes.add(
            _VisualNode(
              id: id,
              label: data.title,
              details: _buildBranchDetailLines(data),
              center: Offset(xCenter, y),
              width: width,
              height: height,
              color: isRoot ? const Color(0xFF4A4E69) : Colors.white,
              borderColor: isRoot ? const Color(0xFF4A4E69) : color,
              textColor: isRoot ? Colors.white : const Color(0xFF333333),
            ),
          );

          if (data.children.isEmpty) {
            return;
          }

          final childWidths = data.children
              .map((child) => subtreeWidth(child, depth + 1))
              .toList();
          final totalChildWidth =
              childWidths.fold<double>(0.0, (a, b) => a + b);
          final usableSpan = math.max(totalChildWidth, xSpan * 0.96);
          var cursor = xCenter - (usableSpan / 2);

          for (var i = 0; i < data.children.length; i++) {
            final child = data.children[i];
            final childSpan = childWidths[i];
            final childX = cursor + (childSpan / 2);
            final childColor = depth == 0 ? colorForDepth(i) : color;
            final childY = topY + ((depth + 1) * levelGap);
            final childHeight = (depth + 1) <= 1 ? 58.0 : 52.0;

            edges.add(
              _VisualEdge(
                from: Offset(xCenter, y + (height / 2)),
                to: Offset(childX, childY - (childHeight / 2)),
                color: childColor,
                bendLeft: false,
                thickness: depth == 0 ? 3.8 : 2.6,
              ),
            );

            layoutNode(
              data: child,
              depth: depth + 1,
              xCenter: childX,
              xSpan: childSpan,
              id: '${id}_$i',
              color: childColor,
            );

            cursor += childSpan;
          }
        }

        layoutNode(
          data: rootData,
          depth: 0,
          xCenter: rootCenter.dx,
          xSpan: canvasWidth - 120,
          id: 'center',
          color: _MindMapCanvas._palette.first,
        );

        return Card(
          margin: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.22,
                  maxScale: 2.8,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(260),
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MindMapEdgePainter(edges: edges),
                          ),
                        ),
                        ...nodes.map((node) => _MindMapNodeWidget(node: node)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _fitToViewport(constraints, canvasWidth, canvasHeight),
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Center'),
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

    return Positioned(
      left: left,
      top: top,
      width: node.width,
      height: node.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showNodeDetails(context, node),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: node.color,
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: node.borderColor ?? node.color, width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                    fontWeight: isCenter ? FontWeight.w700 : FontWeight.w600,
                    height: 1.15,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showNodeDetails(BuildContext context, _VisualNode node) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
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
        ..color = edge.color
        ..strokeWidth = edge.thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(edge.from.dx, edge.from.dy);
      final direction = edge.to.dx >= edge.from.dx ? 1.0 : -1.0;
      final verticalGap = (edge.to.dy - edge.from.dy).abs();
      final bend = math.min(12.0, math.max(6.0, verticalGap * 0.12));
      final midY = edge.from.dy + (verticalGap * 0.5);

      path.lineTo(edge.from.dx, midY - bend);
      path.quadraticBezierTo(
        edge.from.dx,
        midY,
        edge.from.dx + (direction * bend),
        midY,
      );
      path.lineTo(edge.to.dx - (direction * bend), midY);
      path.quadraticBezierTo(
        edge.to.dx,
        midY,
        edge.to.dx,
        midY + bend,
      );
      path.lineTo(edge.to.dx, edge.to.dy);
      canvas.drawPath(path, paint);
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

_ParsedMindMap _parseMindMap(String topic, String content) {
  final lines = content
      .split(RegExp(r'\r?\n'))
      .map(_InputLine.fromRaw)
      .where((line) => line.text.isNotEmpty)
      .toList();

  final headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');

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

  final branchLevel = headings.map((item) => item.level).reduce(math.min);
  final subheadingLevel = branchLevel + 1;

  final rootNodes = <_TreeNode>[];
  _TreeNode? currentBranch;
  _TreeNode? currentSubheading;

  _TreeNode? activeTarget() => currentSubheading ?? currentBranch;

  for (final line in lines) {
    final headingMatch = headingPattern.firstMatch(line.text);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final text = _cleanNodeText(headingMatch.group(2)!);
      if (text.isEmpty) {
        continue;
      }

      if (level <= branchLevel) {
        final node = _TreeNode(level: branchLevel, title: text);
        rootNodes.add(node);
        currentBranch = node;
        currentSubheading = null;
      } else if (level == subheadingLevel) {
        if (currentBranch == null) {
          currentBranch = _TreeNode(level: branchLevel, title: 'General');
          rootNodes.add(currentBranch);
        }
        final node = _TreeNode(level: subheadingLevel, title: text);
        currentBranch.children.add(node);
        currentSubheading = node;
      } else {
        final target = activeTarget();
        if (target != null) {
          target.details.add(text);
        }
      }
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

  final normalized = branchEntries
      .take(12)
      .map(
        (entry) => _BranchData(
          title: entry.title,
          details: entry.details.take(28).toList(),
          children: entry.children
              .take(12)
              .map(
                (child) => _BranchData(
                  title: child.title,
                  details: child.details.take(32).toList(),
                ),
              )
              .toList(),
        ),
      )
      .toList();

  if (normalized.isEmpty) {
    normalized.add(
      const _BranchData(
        title: 'Main Concept',
        children: [
          _BranchData(title: 'Subtopic'),
        ],
      ),
    );
  }

  return _ParsedMindMap(topic: topic, branches: normalized);
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
        RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(normalized);
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

int _maxBranchDepth(List<_BranchData> branches) {
  if (branches.isEmpty) {
    return 1;
  }

  int depthOf(_BranchData node) {
    if (node.children.isEmpty) {
      return 1;
    }
    final childDepth =
        node.children.map(depthOf).fold<int>(0, (maxV, d) => math.max(maxV, d));
    return 1 + childDepth;
  }

  return branches.map(depthOf).fold<int>(1, (maxV, d) => math.max(maxV, d));
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
