import 'package:flutter/material.dart';

import '../services/local_store_service.dart';

class LearningJourneyScreen extends StatefulWidget {
  const LearningJourneyScreen({
    super.key,
    required this.storeService,
  });

  final LocalStoreService storeService;

  @override
  State<LearningJourneyScreen> createState() => _LearningJourneyScreenState();
}

class _LearningJourneyScreenState extends State<LearningJourneyScreen> {
  static const Map<String, _JourneyTemplate> _templates = {
    'physics': _JourneyTemplate(
      key: 'physics',
      subjectLabel: 'Physics',
      subtitle: 'Every formula you master is a law of the universe unlocked.',
      accent: Color(0xFF174A82),
      softAccent: Color(0xFFD9E7F7),
      sections: [
        _JourneySection(title: 'UNDERSTAND THE CONCEPT', tasks: [
          _JourneyTask(
              id: 'phy_uc_1',
              label: 'Read the full chapter once - just get the big picture',
              xp: 10),
          _JourneyTask(
              id: 'phy_uc_2',
              label: 'Identify the key laws and principles',
              xp: 10),
          _JourneyTask(
              id: 'phy_uc_3',
              label: 'Watch a short video or re-read confusing sections',
              xp: 10),
          _JourneyTask(
              id: 'phy_uc_4',
              label: "Visualise what's physically happening (draw it out)",
              xp: 10),
        ]),
        _JourneySection(title: 'BUILD YOUR FORMULA SHEET', tasks: [
          _JourneyTask(
              id: 'phy_fs_1',
              label: 'Write every formula with variable names and SI units',
              xp: 15),
          _JourneyTask(
              id: 'phy_fs_2',
              label: 'Note when each formula applies (conditions/limits)',
              xp: 15),
          _JourneyTask(
              id: 'phy_fs_3',
              label: 'Understand the derivation of at least the main formulas',
              xp: 15),
          _JourneyTask(
              id: 'phy_fs_4',
              label: 'Test yourself: cover and recall each formula from memory',
              xp: 15),
        ]),
        _JourneySection(title: 'SOLVE PROBLEMS', tasks: [
          _JourneyTask(
              id: 'phy_sp_1',
              label: 'Try all in-text examples before looking at the solution',
              xp: 25),
          _JourneyTask(
              id: 'phy_sp_2',
              label: 'Solve all end-of-chapter numerical problems',
              xp: 25),
          _JourneyTask(
              id: 'phy_sp_3',
              label:
                  'For every wrong answer - find the exact mistake (concept? units? formula?)',
              xp: 25),
          _JourneyTask(
              id: 'phy_sp_4',
              label: 'Practise problems of different difficulty levels',
              xp: 25),
          _JourneyTask(
              id: 'phy_sp_5',
              label: 'Check unit consistency in every single answer',
              xp: 25),
        ]),
        _JourneySection(title: 'MASTER & CONNECT', tasks: [
          _JourneyTask(
              id: 'phy_mc_1',
              label: 'Explain the chapter concepts out loud without notes',
              xp: 20),
          _JourneyTask(
              id: 'phy_mc_2',
              label: 'Link this chapter to previous chapters',
              xp: 20),
          _JourneyTask(
              id: 'phy_mc_3',
              label: 'Solve 2 unseen/past exam problems successfully',
              xp: 20),
          _JourneyTask(
              id: 'phy_mc_4',
              label: 'Review after 24 hours and again after 1 week',
              xp: 20),
        ]),
      ],
      milestones: [
        'Formula sheet done - you\'ve got the tools',
        'Half the problems solved - momentum is building',
        'Chapter mastered - you think like a physicist',
      ],
    ),
    'chemistry': _JourneyTemplate(
      key: 'chemistry',
      subjectLabel: 'Chemistry',
      subtitle:
          "Chemistry is just atoms doing maths - and you're in charge now.",
      accent: Color(0xFF7E3418),
      softAccent: Color(0xFFF7E5DF),
      sections: [
        _JourneySection(title: 'UNDERSTAND THE CONCEPT', tasks: [
          _JourneyTask(
              id: 'che_uc_1',
              label: 'Read the chapter once - note unfamiliar terms',
              xp: 10),
          _JourneyTask(
              id: 'che_uc_2',
              label: 'Learn all key definitions and terminology',
              xp: 10),
          _JourneyTask(
              id: 'che_uc_3',
              label: "Understand the 'why' behind each reaction or process",
              xp: 10),
          _JourneyTask(
              id: 'che_uc_4',
              label: 'Spot patterns: periodic trends, reaction types, rules',
              xp: 10),
        ]),
        _JourneySection(title: 'NOTES & REACTIONS', tasks: [
          _JourneyTask(
              id: 'che_nr_1',
              label: 'Write balanced equations for all key reactions',
              xp: 15),
          _JourneyTask(
              id: 'che_nr_2',
              label:
                  'Summarise each reaction type with conditions and observations',
              xp: 15),
          _JourneyTask(
              id: 'che_nr_3',
              label:
                  "Build a formula/constant sheet (molar mass, Avogadro's, etc.)",
              xp: 15),
          _JourneyTask(
              id: 'che_nr_4',
              label: 'Create a mind map linking all concepts in the chapter',
              xp: 15),
        ]),
        _JourneySection(title: 'NUMERICAL PRACTICE', tasks: [
          _JourneyTask(
              id: 'che_np_1',
              label: 'Solve all mole/stoichiometry calculations in the chapter',
              xp: 25),
          _JourneyTask(
              id: 'che_np_2',
              label:
                  'Practice concentration, titration and equilibrium problems',
              xp: 25),
          _JourneyTask(
              id: 'che_np_3',
              label:
                  'For every wrong sum - identify if it was concept or calculation error',
              xp: 25),
          _JourneyTask(
              id: 'che_np_4',
              label: 'Re-do all in-text worked examples from scratch',
              xp: 25),
        ]),
        _JourneySection(title: 'MASTER & CONNECT', tasks: [
          _JourneyTask(
              id: 'che_mc_1',
              label: 'Write a summary of the chapter in your own words',
              xp: 20),
          _JourneyTask(
              id: 'che_mc_2',
              label: 'Link reactions to real-life applications',
              xp: 20),
          _JourneyTask(
              id: 'che_mc_3',
              label: 'Attempt past exam questions from this chapter',
              xp: 20),
          _JourneyTask(
              id: 'che_mc_4',
              label: 'Review after 24 hours and again after 1 week',
              xp: 20),
        ]),
      ],
      milestones: [
        'Reactions balanced - the lab is yours',
        'Calculations cracked - numbers bow to you',
        'Chapter complete - you are the chemist',
      ],
    ),
    'maths': _JourneyTemplate(
      key: 'maths',
      subjectLabel: 'Maths',
      subtitle: 'Maths rewards stubbornness. Every hard problem is beatable.',
      accent: Color(0xFF3E3D8C),
      softAccent: Color(0xFFE4E3F8),
      sections: [
        _JourneySection(title: 'UNDERSTAND THE CONCEPT', tasks: [
          _JourneyTask(
              id: 'mat_uc_1',
              label: 'Read through the chapter and understand the core idea',
              xp: 10),
          _JourneyTask(
              id: 'mat_uc_2',
              label: 'Study each worked example step by step',
              xp: 10),
          _JourneyTask(
              id: 'mat_uc_3',
              label: 'Identify which type of problem each method solves',
              xp: 10),
          _JourneyTask(
              id: 'mat_uc_4',
              label: 'Note any special cases, exceptions or edge conditions',
              xp: 10),
        ]),
        _JourneySection(title: 'FORMULA & METHOD SHEET', tasks: [
          _JourneyTask(
              id: 'mat_fm_1',
              label: 'Write all formulas, identities and theorems',
              xp: 15),
          _JourneyTask(
              id: 'mat_fm_2',
              label: 'Note the exact steps/method for each problem type',
              xp: 15),
          _JourneyTask(
              id: 'mat_fm_3',
              label:
                  'Understand where each formula comes from (prove it if possible)',
              xp: 15),
          _JourneyTask(
              id: 'mat_fm_4',
              label: 'Cover and recall each formula and method from memory',
              xp: 15),
        ]),
        _JourneySection(title: 'PRACTICE PROBLEMS', tasks: [
          _JourneyTask(
              id: 'mat_pp_1',
              label: 'Solve all basic/introductory exercise questions',
              xp: 30),
          _JourneyTask(
              id: 'mat_pp_2',
              label: 'Move to intermediate problems once basics are solid',
              xp: 30),
          _JourneyTask(
              id: 'mat_pp_3',
              label: 'Attempt harder/challenge problems without hints first',
              xp: 30),
          _JourneyTask(
              id: 'mat_pp_4',
              label:
                  'For every wrong answer - find the exact step where it went wrong',
              xp: 30),
          _JourneyTask(
              id: 'mat_pp_5',
              label: 'Re-solve incorrect problems from scratch the next day',
              xp: 30),
          _JourneyTask(
              id: 'mat_pp_6',
              label:
                  'Time yourself on a set of problems - simulate exam pressure',
              xp: 30),
        ]),
        _JourneySection(title: 'MASTER & CONNECT', tasks: [
          _JourneyTask(
              id: 'mat_mc_1',
              label: "Explain the method out loud as if teaching someone",
              xp: 20),
          _JourneyTask(
              id: 'mat_mc_2',
              label: 'Identify how this chapter links to other topics',
              xp: 20),
          _JourneyTask(
              id: 'mat_mc_3',
              label: 'Attempt full past exam questions on this chapter',
              xp: 20),
          _JourneyTask(
              id: 'mat_mc_4',
              label: 'Review after 24 hours and again after 1 week',
              xp: 20),
        ]),
      ],
      milestones: [
        'Methods memorised - your toolkit is ready',
        "Half the problems done - you're unstoppable",
        'Chapter conquered - you are a mathematician',
      ],
    ),
    'biology': _JourneyTemplate(
      key: 'biology',
      subjectLabel: 'Biology',
      subtitle: "Biology is life itself - and you're learning to read it.",
      accent: Color(0xFF2D5B1C),
      softAccent: Color(0xFFE7F0DC),
      sections: [
        _JourneySection(title: 'UNDERSTAND THE CONCEPT', tasks: [
          _JourneyTask(
              id: 'bio_uc_1',
              label: 'Read the full chapter once - enjoy the story of life',
              xp: 10),
          _JourneyTask(
              id: 'bio_uc_2',
              label: 'Highlight all key terms, organisms and processes',
              xp: 10),
          _JourneyTask(
              id: 'bio_uc_3',
              label: "Understand the 'why' - what is the function/purpose?",
              xp: 10),
          _JourneyTask(
              id: 'bio_uc_4',
              label: 'Draw or label all key diagrams (cells, cycles, systems)',
              xp: 10),
        ]),
        _JourneySection(title: 'NOTES & DIAGRAMS', tasks: [
          _JourneyTask(
              id: 'bio_nd_1',
              label:
                  'Write definitions of every bold/key term in your own words',
              xp: 20),
          _JourneyTask(
              id: 'bio_nd_2',
              label: 'Redraw all important diagrams from memory and label them',
              xp: 20),
          _JourneyTask(
              id: 'bio_nd_3',
              label:
                  'Create a flowchart for all processes (e.g. photosynthesis, digestion)',
              xp: 20),
          _JourneyTask(
              id: 'bio_nd_4',
              label:
                  'Build a comparison table for similar concepts (e.g. mitosis vs meiosis)',
              xp: 20),
          _JourneyTask(
              id: 'bio_nd_5',
              label: 'Summarise each section in 3-4 bullet points',
              xp: 20),
        ]),
        _JourneySection(title: 'ACTIVE RECALL', tasks: [
          _JourneyTask(
              id: 'bio_ar_1',
              label:
                  'Cover notes and answer all end-of-chapter questions from memory',
              xp: 25),
          _JourneyTask(
              id: 'bio_ar_2',
              label: 'Use flashcards for definitions and processes',
              xp: 25),
          _JourneyTask(
              id: 'bio_ar_3',
              label: 'Explain each diagram out loud without looking',
              xp: 25),
          _JourneyTask(
              id: 'bio_ar_4',
              label: 'Quiz yourself on the function of each structure/organ',
              xp: 25),
        ]),
        _JourneySection(title: 'MASTER & CONNECT', tasks: [
          _JourneyTask(
              id: 'bio_mc_1',
              label:
                  'Link this chapter to real-world examples (diseases, evolution, ecology)',
              xp: 20),
          _JourneyTask(
              id: 'bio_mc_2',
              label: 'Identify connections to other chapters',
              xp: 20),
          _JourneyTask(
              id: 'bio_mc_3',
              label:
                  'Attempt past exam questions and structured answer questions',
              xp: 20),
          _JourneyTask(
              id: 'bio_mc_4',
              label: 'Review after 24 hours and again after 1 week',
              xp: 20),
        ]),
      ],
      milestones: [
        'Diagrams drawn - you see what the textbook sees',
        'Recall tested - the knowledge is inside you now',
        'Chapter mastered - life holds no secrets from you',
      ],
    ),
    'optional': _JourneyTemplate(
      key: 'optional',
      subjectLabel: 'Optional',
      subtitle: 'Build your own learning path, your own way.',
      accent: Color(0xFF225E63),
      softAccent: Color(0xFFDFF1F2),
      sections: [],
      milestones: [],
    ),
  };

  final TextEditingController _examNameController = TextEditingController();
  String _selectedSubject = 'physics';
  Set<String> _completedTaskIds = <String>{};
  Map<String, List<_JourneyTask>> _otherTasksBySubject =
      <String, List<_JourneyTask>>{};
  List<_JourneyTask> _optionalTasks = <_JourneyTask>[];
  List<String> _optionalMilestones = <String>[];
  int _customTaskCounter = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await widget.storeService.loadLearningJourneyState();
    if (!mounted) {
      return;
    }

    if (state != null) {
      final subjectFromState = state['subject']?.toString() ?? _selectedSubject;
      final completed =
          (state['completedTaskIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toSet();
      final loadedOtherBySubject = <String, List<_JourneyTask>>{};
      final rawOtherBySubject =
          state['otherTasksBySubject'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawOtherBySubject.entries) {
        final tasks = (entry.value as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_taskFromJson)
            .toList();
        loadedOtherBySubject[entry.key] = tasks;
      }

      final loadedOptionalTasks =
          (state['optionalTasks'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_taskFromJson)
              .toList();

      final loadedOptionalMilestones =
          (state['optionalMilestones'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();

      setState(() {
        _examNameController.text = state['examName']?.toString() ?? '';
        _selectedSubject = _templates.containsKey(subjectFromState)
            ? subjectFromState
            : _selectedSubject;
        _completedTaskIds = completed;
        _otherTasksBySubject = loadedOtherBySubject;
        _optionalTasks = loadedOptionalTasks;
        _optionalMilestones = loadedOptionalMilestones;
        _customTaskCounter =
            int.tryParse(state['customTaskCounter']?.toString() ?? '') ?? 0;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveState() async {
    final otherJson = <String, List<Map<String, dynamic>>>{};
    for (final entry in _otherTasksBySubject.entries) {
      otherJson[entry.key] = entry.value.map(_taskToJson).toList();
    }

    await widget.storeService.saveLearningJourneyState({
      'examName': _examNameController.text.trim(),
      'subject': _selectedSubject,
      'completedTaskIds': _completedTaskIds.toList(),
      'otherTasksBySubject': otherJson,
      'optionalTasks': _optionalTasks.map(_taskToJson).toList(),
      'optionalMilestones': _optionalMilestones,
      'customTaskCounter': _customTaskCounter,
    });
  }

  Map<String, dynamic> _taskToJson(_JourneyTask task) {
    return {
      'id': task.id,
      'label': task.label,
      'xp': task.xp,
    };
  }

  _JourneyTask _taskFromJson(Map<String, dynamic> json) {
    final xp = int.tryParse(json['xp']?.toString() ?? '') ?? 10;
    return _JourneyTask(
      id: json['id']?.toString() ??
          'custom_${DateTime.now().microsecondsSinceEpoch}',
      label: json['label']?.toString() ?? 'Custom checklist',
      xp: xp,
    );
  }

  Future<void> _toggleTask(String taskId, bool isDone) async {
    final allBefore = _allTasksForCurrentSubject();
    final wasComplete = _isJourneyComplete(allBefore, _completedTaskIds);

    setState(() {
      if (isDone) {
        _completedTaskIds.add(taskId);
      } else {
        _completedTaskIds.remove(taskId);
      }
    });

    await _saveState();

    final allAfter = _allTasksForCurrentSubject();
    final nowComplete = _isJourneyComplete(allAfter, _completedTaskIds);
    if (!wasComplete && nowComplete) {
      final template = _templates[_selectedSubject]!;
      await _showCompletionAwardDialog(_selectedSubject, template.subjectLabel);
      await _clearJourneyForFreshStart();
    }
  }

  Future<void> _changeSubject(String subjectKey) async {
    if (_selectedSubject == subjectKey) {
      return;
    }
    setState(() {
      _selectedSubject = subjectKey;
      _completedTaskIds = <String>{};
    });
    await _saveState();
  }

  List<_JourneyTask> _allTasksForCurrentSubject() {
    final template = _templates[_selectedSubject]!;
    final fixed = <_JourneyTask>[];
    for (final section in template.sections) {
      fixed.addAll(section.tasks);
    }

    if (_selectedSubject == 'optional') {
      return <_JourneyTask>[..._optionalTasks];
    }

    final other =
        _otherTasksBySubject[_selectedSubject] ?? const <_JourneyTask>[];
    return <_JourneyTask>[...fixed, ...other];
  }

  Future<void> _resetJourney() async {
    setState(() {
      _completedTaskIds = <String>{};
    });
    await _saveState();
  }

  bool _isJourneyComplete(
      List<_JourneyTask> tasks, Set<String> completedTaskIds) {
    for (final task in tasks) {
      if (!completedTaskIds.contains(task.id)) {
        return false;
      }
    }
    return tasks.isNotEmpty;
  }

  Future<void> _showCompletionAwardDialog(
    String subjectKey,
    String subjectLabel,
  ) async {
    if (!mounted) {
      return;
    }

    final badge = _badgeForSubject(subjectKey, subjectLabel);
    final message = _motivationalMessageForSubject(subjectKey, subjectLabel);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _JourneyCelebrationDialog(
          badge: badge,
          message: message,
          onThanks: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  _SubjectBadgeData _badgeForSubject(String subjectKey, String subjectLabel) {
    switch (subjectKey) {
      case 'physics':
        return _SubjectBadgeData(
          title: 'Ace in Physics',
          icon: Icons.bolt_rounded,
          color: const Color(0xFF1565C0),
        );
      case 'chemistry':
        return _SubjectBadgeData(
          title: 'Ace in Chemistry',
          icon: Icons.science_rounded,
          color: const Color(0xFF8D3F24),
        );
      case 'maths':
        return _SubjectBadgeData(
          title: 'Ace in Maths',
          icon: Icons.functions_rounded,
          color: const Color(0xFF3949AB),
        );
      case 'biology':
        return _SubjectBadgeData(
          title: 'Ace in Biology',
          icon: Icons.eco_rounded,
          color: const Color(0xFF2E7D32),
        );
      case 'optional':
        return _SubjectBadgeData(
          title: 'Ace in Optional',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF00695C),
        );
      default:
        return _SubjectBadgeData(
          title: 'Ace in $subjectLabel',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF455A64),
        );
    }
  }

  String _motivationalMessageForSubject(
      String subjectKey, String subjectLabel) {
    switch (subjectKey) {
      case 'physics':
        return 'You solved with clarity and logic. Keep that momentum and the next chapter will feel lighter.';
      case 'chemistry':
        return 'Brilliant consistency. You turned reactions into intuition, one smart step at a time.';
      case 'maths':
        return 'That was pure discipline. Hard problems bend when you stay with them.';
      case 'biology':
        return 'Excellent recall and connection-making. You are thinking like a true biologist now.';
      case 'optional':
        return 'You designed your own journey and conquered it. That is real ownership of learning.';
      default:
        return 'You completed your $subjectLabel journey with focus and grit. Keep building that streak.';
    }
  }

  Future<void> _clearJourneyForFreshStart() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _examNameController.clear();
      _selectedSubject = 'physics';
      _completedTaskIds = <String>{};
      _otherTasksBySubject = <String, List<_JourneyTask>>{};
      _optionalTasks = <_JourneyTask>[];
      _optionalMilestones = <String>[];
      _customTaskCounter = 0;
    });

    await widget.storeService.saveLearningJourneyState(null);
  }

  Future<void> _addChecklistToOther() async {
    final input =
        await _showAddChecklistDialog(title: 'Add checklist to OTHER');
    if (input == null) {
      return;
    }

    final nextTask = _JourneyTask(
      id: 'other_${_selectedSubject}_${_customTaskCounter++}',
      label: input.label,
      xp: input.xp,
    );

    setState(() {
      final current = List<_JourneyTask>.from(
          _otherTasksBySubject[_selectedSubject] ?? const <_JourneyTask>[]);
      current.add(nextTask);
      _otherTasksBySubject[_selectedSubject] = current;
    });
    await _saveState();
  }

  Future<void> _addChecklistToOptional() async {
    final input =
        await _showAddChecklistDialog(title: 'Add checklist to OPTIONAL');
    if (input == null) {
      return;
    }

    setState(() {
      _optionalTasks = <_JourneyTask>[
        ..._optionalTasks,
        _JourneyTask(
          id: 'optional_${_customTaskCounter++}',
          label: input.label,
          xp: input.xp,
        ),
      ];
    });
    await _saveState();
  }

  Future<_ChecklistInput?> _showAddChecklistDialog(
      {required String title}) async {
    final controller = TextEditingController();
    var selectedXp = 15;

    final result = await showDialog<_ChecklistInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(labelText: 'Checklist item'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedXp,
                    decoration: const InputDecoration(labelText: 'XP'),
                    items: const [5, 10, 15, 20, 25, 30]
                        .map(
                          (xp) => DropdownMenuItem<int>(
                            value: xp,
                            child: Text('$xp XP'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() {
                        selectedXp = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _ChecklistInput(label: text, xp: selectedXp),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _removeCustomTask(String taskId) async {
    setState(() {
      _completedTaskIds.remove(taskId);
      if (_selectedSubject == 'optional') {
        _optionalTasks =
            _optionalTasks.where((task) => task.id != taskId).toList();
      } else {
        final current = List<_JourneyTask>.from(
            _otherTasksBySubject[_selectedSubject] ?? const <_JourneyTask>[]);
        current.removeWhere((task) => task.id == taskId);
        _otherTasksBySubject[_selectedSubject] = current;
      }
    });
    await _saveState();
  }

  Future<void> _addOptionalMilestone() async {
    final text = await _showSimpleTextInputDialog(
      title: 'Add milestone',
      label: 'Milestone text',
    );
    if (text == null) {
      return;
    }
    setState(() {
      _optionalMilestones = <String>[..._optionalMilestones, text];
    });
    await _saveState();
  }

  Future<void> _editOptionalMilestone(int index) async {
    if (index < 0 || index >= _optionalMilestones.length) {
      return;
    }
    final updated = await _showSimpleTextInputDialog(
      title: 'Edit milestone',
      label: 'Milestone text',
      initialValue: _optionalMilestones[index],
    );
    if (updated == null) {
      return;
    }
    setState(() {
      _optionalMilestones[index] = updated;
    });
    await _saveState();
  }

  Future<void> _deleteOptionalMilestone(int index) async {
    if (index < 0 || index >= _optionalMilestones.length) {
      return;
    }
    setState(() {
      _optionalMilestones.removeAt(index);
    });
    await _saveState();
  }

  Future<String?> _showSimpleTextInputDialog({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  void dispose() {
    _examNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final template = _templates[_selectedSubject]!;
    final otherTasks =
        _otherTasksBySubject[_selectedSubject] ?? const <_JourneyTask>[];
    final allTasks = _allTasksForCurrentSubject();
    final totalXp = allTasks.fold<int>(0, (sum, item) => sum + item.xp);
    final earnedXp = allTasks
        .where((task) => _completedTaskIds.contains(task.id))
        .fold<int>(0, (sum, item) => sum + item.xp);
    final progress = totalXp == 0 ? 0.0 : earnedXp / totalXp;
    final milestones = _selectedSubject == 'optional'
        ? _optionalMilestones
        : template.milestones;
    final milestoneCount = _achievedMilestones(progress, milestones.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start A Learning Journey',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _examNameController,
                  decoration: const InputDecoration(
                    labelText: 'Exam name',
                    hintText: 'e.g. Mid-term 2026',
                  ),
                  onChanged: (_) => _saveState(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: _templates.values
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.key,
                          child: Text(item.subjectLabel),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _changeSubject(value);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _saveState,
                      icon: const Icon(Icons.rocket_launch_outlined),
                      label: const Text('Save Journey'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _resetJourney,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Reset Progress'),
                    ),
                    if (_selectedSubject == 'optional')
                      OutlinedButton.icon(
                        onPressed: _addChecklistToOptional,
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Add Checklist'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _addChecklistToOther,
                        icon: const Icon(Icons.playlist_add_outlined),
                        label: const Text('Add To OTHER'),
                      ),
                    if (_selectedSubject == 'optional')
                      OutlinedButton.icon(
                        onPressed: _addOptionalMilestone,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Add Milestone'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _JourneyHeader(
          examName: _examNameController.text.trim(),
          template: template,
          earnedXp: earnedXp,
          totalXp: totalXp,
          progress: progress,
        ),
        const SizedBox(height: 12),
        if (_selectedSubject != 'optional')
          ...template.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _JourneySectionCard(
                section: section,
                completedTaskIds: _completedTaskIds,
                onChanged: (taskId, isDone) => _toggleTask(taskId, isDone),
              ),
            ),
          ),
        if (_selectedSubject != 'optional' && otherTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _JourneySectionCard(
              section: _JourneySection(title: 'OTHER', tasks: otherTasks),
              completedTaskIds: _completedTaskIds,
              onChanged: (taskId, isDone) => _toggleTask(taskId, isDone),
              editable: true,
              onDeleteTask: _removeCustomTask,
            ),
          ),
        if (_selectedSubject == 'optional')
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _JourneySectionCard(
              section: _JourneySection(
                  title: 'YOUR CHECKLISTS', tasks: _optionalTasks),
              completedTaskIds: _completedTaskIds,
              onChanged: (taskId, isDone) => _toggleTask(taskId, isDone),
              editable: true,
              onDeleteTask: _removeCustomTask,
            ),
          ),
        if (_selectedSubject == 'optional' && _optionalMilestones.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionalMilestoneEditor(
              milestones: _optionalMilestones,
              onEdit: _editOptionalMilestone,
              onDelete: _deleteOptionalMilestone,
            ),
          ),
        _MilestoneCard(
          milestones: milestones,
          achievedCount: milestoneCount,
        ),
      ],
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.examName,
    required this.template,
    required this.earnedXp,
    required this.totalXp,
    required this.progress,
  });

  final String examName;
  final _JourneyTemplate template;
  final int earnedXp;
  final int totalXp;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: template.softAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examName.isEmpty
                          ? '${template.subjectLabel} chapter checklist'
                          : '$examName • ${template.subjectLabel}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: template.accent,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.subtitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: template.accent.withValues(alpha: 0.82),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: template.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$earnedXp / $totalXp XP',
                  style: TextStyle(
                    color: template.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: template.accent.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(template.accent),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: template.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneySectionCard extends StatelessWidget {
  const _JourneySectionCard({
    required this.section,
    required this.completedTaskIds,
    required this.onChanged,
    this.editable = false,
    this.onDeleteTask,
  });

  final _JourneySection section;
  final Set<String> completedTaskIds;
  final void Function(String taskId, bool isDone) onChanged;
  final bool editable;
  final Future<void> Function(String taskId)? onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${section.title} +${section.xpEach} XP EACH',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
        ),
        const SizedBox(height: 8),
        ...section.tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _JourneyTaskTile(
              task: task,
              isChecked: completedTaskIds.contains(task.id),
              onChanged: (value) => onChanged(task.id, value),
              editable: editable,
              onDelete: onDeleteTask == null
                  ? null
                  : () {
                      onDeleteTask!(task.id);
                    },
            ),
          ),
        ),
      ],
    );
  }
}

class _JourneyTaskTile extends StatelessWidget {
  const _JourneyTaskTile({
    required this.task,
    required this.isChecked,
    required this.onChanged,
    this.editable = false,
    this.onDelete,
  });

  final _JourneyTask task;
  final bool isChecked;
  final ValueChanged<bool> onChanged;
  final bool editable;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isChecked
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.35)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            onChanged: (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '+${task.xp} XP',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (editable && onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete checklist item',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionalMilestoneEditor extends StatelessWidget {
  const _OptionalMilestoneEditor({
    required this.milestones,
    required this.onEdit,
    required this.onDelete,
  });

  final List<String> milestones;
  final Future<void> Function(int index) onEdit;
  final Future<void> Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EDIT OPTIONAL MILESTONES',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            ...List.generate(milestones.length, (index) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text(milestones[index]),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(index),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestones,
    required this.achievedCount,
  });

  final List<String> milestones;
  final int achievedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MILESTONES',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            ...List.generate(milestones.length, (index) {
              final done = index < achievedCount;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: done
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.35)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  color: done
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.25)
                      : Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: done
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        milestones[index],
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _JourneyTemplate {
  const _JourneyTemplate({
    required this.key,
    required this.subjectLabel,
    required this.subtitle,
    required this.accent,
    required this.softAccent,
    required this.sections,
    required this.milestones,
  });

  final String key;
  final String subjectLabel;
  final String subtitle;
  final Color accent;
  final Color softAccent;
  final List<_JourneySection> sections;
  final List<String> milestones;

  int get totalXp {
    var total = 0;
    for (final section in sections) {
      for (final task in section.tasks) {
        total += task.xp;
      }
    }
    return total;
  }

  int earnedXp(Set<String> completedTaskIds) {
    var earned = 0;
    for (final section in sections) {
      for (final task in section.tasks) {
        if (completedTaskIds.contains(task.id)) {
          earned += task.xp;
        }
      }
    }
    return earned;
  }
}

class _JourneySection {
  const _JourneySection({
    required this.title,
    required this.tasks,
  });

  final String title;
  final List<_JourneyTask> tasks;

  int get xpEach => tasks.isEmpty ? 0 : tasks.first.xp;
}

class _JourneyTask {
  const _JourneyTask({
    required this.id,
    required this.label,
    required this.xp,
  });

  final String id;
  final String label;
  final int xp;
}

class _ChecklistInput {
  const _ChecklistInput({required this.label, required this.xp});

  final String label;
  final int xp;
}

class _SubjectBadgeData {
  const _SubjectBadgeData({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}

class _JourneyCelebrationDialog extends StatefulWidget {
  const _JourneyCelebrationDialog({
    required this.badge,
    required this.message,
    required this.onThanks,
  });

  final _SubjectBadgeData badge;
  final String message;
  final VoidCallback onThanks;

  @override
  State<_JourneyCelebrationDialog> createState() =>
      _JourneyCelebrationDialogState();
}

class _JourneyCelebrationDialogState extends State<_JourneyCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fade.value,
              child: Transform.scale(
                scale: 0.85 + (0.15 * _scale.value),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 98,
                    height: 98,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.badge.color.withValues(alpha: 0.16),
                          widget.badge.color.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: widget.badge.color,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(widget.badge.icon, color: Colors.white, size: 34),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Journey Complete!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.badge.title,
                  style: TextStyle(
                    color: widget.badge.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onThanks,
                  icon: const Icon(Icons.celebration_outlined),
                  label: const Text('Thanks'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _achievedMilestones(double progress, int count) {
  if (count <= 0) {
    return 0;
  }

  final thresholds = <double>[];
  for (var i = 1; i <= count; i++) {
    thresholds.add(i / count);
  }

  var achieved = 0;
  for (final threshold in thresholds) {
    if (progress >= threshold) {
      achieved += 1;
    }
  }
  return achieved;
}
