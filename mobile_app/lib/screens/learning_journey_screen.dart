// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import 'notes_library_screen.dart';
import 'notes_screen.dart';
import '../services/chat_api_service.dart';
import '../services/file_selection_service.dart';
import '../services/journey_task_overlay_service.dart';
import '../services/local_store_service.dart';
import 'worksheet_screen.dart';
import 'worksheets_library_screen.dart';

class LearningJourneyScreen extends StatefulWidget {
  const LearningJourneyScreen({
    super.key,
    required this.storeService,
    this.journeyId,
    this.startFresh = false,
  });

  final LocalStoreService storeService;
  final String? journeyId;
  final bool startFresh;

  @override
  State<LearningJourneyScreen> createState() => _LearningJourneyScreenState();
}

class _LearningJourneyScreenState extends State<LearningJourneyScreen> {
  static const Set<String> _enabledSubjects = <String>{
    'physics',
    'chemistry',
    'maths',
    'biology',
    'optional',
  };
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
              label: 'Explain the method out loud as if teaching someone',
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
              label: 'Explain the method out loud as if teaching someone',
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
  final ScrollController _scrollController = ScrollController();
  String _selectedSubject = 'physics';
  Set<String> _completedTaskIds = <String>{};
  Map<String, List<_JourneyTask>> _otherTasksBySubject =
      <String, List<_JourneyTask>>{};
  List<_JourneyTask> _optionalTasks = <_JourneyTask>[];
  List<String> _optionalMilestones = <String>[];
  int _customTaskCounter = 0;
  bool _loading = true;
  bool _isJourneySaved = false;
  bool _showJourneySetup = true;
  String? _journeyId;
  final ChatApiService _chatService =
      ChatApiService(baseUrl: AppConfig.backendBaseUrl);
  final FileSelectionService _fileSelectionService = FileSelectionService();
  final TextEditingController _flashcardAnswerController =
      TextEditingController();

  int _journeyMarks = 20;
  int _totalStudyMinutes = 60;
  List<_ChapterWeightage> _chapterWeightages = <_ChapterWeightage>[];
  String _twentyMarkTopicReference = '';
  String _learningStage = 'tasks';
  int _taskQueueIndex = 0;
  int _taskRemainingSeconds = 0;
  Map<String, int> _taskDurations = <String, int>{};
  Timer? _taskTimer;
  bool _taskSessionStarted = false;
  bool _taskOverlayEnabled = false;
  Timer? _progressPersistTimer;

  bool _generatingJourneyAssets = false;
  List<_FlashcardItem> _flashcards = <_FlashcardItem>[];
  int _flashcardIndex = 0;
  bool _flashcardFlipped = false;
  int _flashcardCorrectCount = 0;
  final Map<int, bool> _flashcardResults = <int, bool>{};
  final Map<int, String> _flashcardUserAnswers = <int, String>{};

  List<_MockQuestion> _mockQuestions = <_MockQuestion>[];
  final Map<int, dynamic> _mockUserAnswers = <int, dynamic>{};
  final Map<int, _ImageAnswerAttachment> _mockImageAnswers =
      <int, _ImageAnswerAttachment>{};
  final Map<int, double> _mockAwardedMarks = <int, double>{};
  final Map<int, String> _mockEvaluationNotes = <int, String>{};
  bool _mockSubmitted = false;
  double _mockTotalAwarded = 0;

  List<Map<String, dynamic>> _savedMockTests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _savedFlashcardSets = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    Map<String, dynamic>? state;
    if (widget.startFresh) {
      state = null;
    } else if (widget.journeyId != null &&
        widget.journeyId!.trim().isNotEmpty) {
      final record = await widget.storeService
          .loadLearningJourneyRecord(widget.journeyId!);
      state = record?.state;
    } else {
      state = await widget.storeService.loadLearningJourneyState();
    }

    if (!mounted) {
      return;
    }

    if (state != null) {
      final loadedState = state;
      final subjectFromState =
          loadedState['subject']?.toString() ?? _selectedSubject;
      final completed = (loadedState['completedTaskIds'] as List<dynamic>? ??
              const <dynamic>[])
          .map((item) => item.toString())
          .toSet();
      final loadedOtherBySubject = <String, List<_JourneyTask>>{};
      final rawOtherBySubject =
          loadedState['otherTasksBySubject'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawOtherBySubject.entries) {
        final tasks = (entry.value as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_taskFromJson)
            .toList();
        loadedOtherBySubject[entry.key] = tasks;
      }

      final loadedOptionalTasks =
          (loadedState['optionalTasks'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_taskFromJson)
              .toList();

      final loadedOptionalMilestones =
          (loadedState['optionalMilestones'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();

      final loadedChapters =
          (loadedState['chapterWeightages'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_ChapterWeightage.fromJson)
              .toList();
      final loadedFlashcards =
          (loadedState['generatedFlashcards'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_FlashcardItem.fromJson)
              .toList();
      final loadedMockQuestions =
          (loadedState['generatedMockQuestions'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_MockQuestion.fromJson)
              .toList();
      final loadedSavedTests =
          (loadedState['savedMockTests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
      final loadedSavedDecks =
          (loadedState['savedFlashcardSets'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
      final loadedFlashcardResults = <int, bool>{};
      final rawFlashcardResults =
          loadedState['flashcardResults'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawFlashcardResults.entries) {
        final index = int.tryParse(entry.key);
        if (index == null) {
          continue;
        }
        loadedFlashcardResults[index] = entry.value == true;
      }
      final loadedFlashcardUserAnswers = <int, String>{};
      final rawFlashcardUserAnswers =
          loadedState['flashcardUserAnswers'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawFlashcardUserAnswers.entries) {
        final index = int.tryParse(entry.key);
        if (index == null) {
          continue;
        }
        loadedFlashcardUserAnswers[index] = entry.value?.toString() ?? '';
      }
      final loadedMockUserAnswers = <int, dynamic>{};
      final rawMockUserAnswers =
          loadedState['mockUserAnswers'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawMockUserAnswers.entries) {
        final index = int.tryParse(entry.key);
        if (index == null) {
          continue;
        }
        loadedMockUserAnswers[index] = entry.value;
      }
      final loadedMockImageAnswers = <int, _ImageAnswerAttachment>{};
      final rawMockImageAnswers =
          loadedState['mockImageAnswers'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawMockImageAnswers.entries) {
        final index = int.tryParse(entry.key);
        final json = entry.value;
        if (index == null || json is! Map<String, dynamic>) {
          continue;
        }
        loadedMockImageAnswers[index] = _ImageAnswerAttachment.fromJson(json);
      }
      final loadedMockAwardedMarks = <int, double>{};
      final rawMockAwarded =
          loadedState['mockAwardedMarks'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawMockAwarded.entries) {
        final index = int.tryParse(entry.key);
        if (index == null) {
          continue;
        }
        loadedMockAwardedMarks[index] =
            double.tryParse(entry.value.toString()) ?? 0;
      }
      final loadedMockNotes = <int, String>{};
      final rawMockNotes =
          loadedState['mockEvaluationNotes'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawMockNotes.entries) {
        final index = int.tryParse(entry.key);
        if (index == null) {
          continue;
        }
        loadedMockNotes[index] = entry.value?.toString() ?? '';
      }
      final loadedTaskDurations = <String, int>{};
      final rawDurations =
          loadedState['taskDurations'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      for (final entry in rawDurations.entries) {
        loadedTaskDurations[entry.key] =
            int.tryParse(entry.value.toString()) ?? 60;
      }

      setState(() {
        _examNameController.text = loadedState['examName']?.toString() ?? '';
        _journeyId = loadedState['id']?.toString() ?? widget.journeyId;
        _selectedSubject = _enabledSubjects.contains(subjectFromState)
            ? subjectFromState
            : 'physics';
        _completedTaskIds = completed;
        _otherTasksBySubject = loadedOtherBySubject;
        _optionalTasks = loadedOptionalTasks;
        _optionalMilestones = loadedOptionalMilestones;
        _customTaskCounter =
            int.tryParse(loadedState['customTaskCounter']?.toString() ?? '') ??
                0;
        _journeyMarks =
            int.tryParse(loadedState['journeyMarks']?.toString() ?? '') ?? 20;
        _totalStudyMinutes =
            int.tryParse(loadedState['totalStudyMinutes']?.toString() ?? '') ??
                60;
        _chapterWeightages = loadedChapters;
        _twentyMarkTopicReference =
            loadedState['twentyMarkTopicReference']?.toString() ?? '';
        final loadedStage = loadedState['learningStage']?.toString() ?? 'tasks';
        _learningStage =
            (loadedStage == 'flashcards' || loadedStage == 'mock_test')
                ? 'resources'
                : loadedStage;
        _taskQueueIndex =
            int.tryParse(loadedState['taskQueueIndex']?.toString() ?? '') ?? 0;
        _taskRemainingSeconds = int.tryParse(
                loadedState['taskRemainingSeconds']?.toString() ?? '') ??
            0;
        _taskSessionStarted = loadedState['taskSessionStarted'] == true;
        _taskOverlayEnabled = loadedState['taskOverlayEnabled'] == true;
        _taskDurations = loadedTaskDurations;
        _flashcards = loadedFlashcards;
        _flashcardIndex =
            int.tryParse(loadedState['flashcardIndex']?.toString() ?? '') ?? 0;
        _flashcardFlipped = loadedState['flashcardFlipped'] == true;
        _flashcardCorrectCount = int.tryParse(
                loadedState['flashcardCorrectCount']?.toString() ?? '') ??
            0;
        _flashcardResults
          ..clear()
          ..addAll(loadedFlashcardResults);
        _flashcardUserAnswers
          ..clear()
          ..addAll(loadedFlashcardUserAnswers);
        _mockQuestions = loadedMockQuestions;
        _mockUserAnswers
          ..clear()
          ..addAll(loadedMockUserAnswers);
        _mockImageAnswers
          ..clear()
          ..addAll(loadedMockImageAnswers);
        _mockAwardedMarks
          ..clear()
          ..addAll(loadedMockAwardedMarks);
        _mockEvaluationNotes
          ..clear()
          ..addAll(loadedMockNotes);
        _mockSubmitted = loadedState['mockSubmitted'] == true;
        _mockTotalAwarded = double.tryParse(
                loadedState['mockTotalAwarded']?.toString() ?? '') ??
            0;
        _savedMockTests = loadedSavedTests;
        _savedFlashcardSets = loadedSavedDecks;
        _loading = false;
        _isJourneySaved = true;
        _showJourneySetup = false;
      });
      _initializeTaskQueue(startIfNeeded: false);
      if (_learningStage == 'tasks' && _isJourneySaved && _taskSessionStarted) {
        _startTaskTimerForCurrentTask();
      }
      _syncTaskOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveState({
    bool showFeedback = false,
    bool markSaved = false,
    bool scrollToTop = false,
  }) async {
    final examName = _examNameController.text.trim();
    final subjectLabel =
        _templates[_selectedSubject]?.subjectLabel ?? 'Journey';
    final allTasks = _allTasksForCurrentSubject();
    final totalTasks = allTasks.length;
    final title = examName.isEmpty ? '$subjectLabel Journey' : examName;

    final saveId = _journeyId ??
        'learning_journey_${DateTime.now().microsecondsSinceEpoch}';

    final otherJson = <String, List<Map<String, dynamic>>>{};
    for (final entry in _otherTasksBySubject.entries) {
      otherJson[entry.key] = entry.value.map(_taskToJson).toList();
    }

    await widget.storeService.saveLearningJourneyState({
      'id': saveId,
      'title': title,
      'examName': examName,
      'subject': _selectedSubject,
      'journeyMarks': _journeyMarks,
      'totalStudyMinutes': _totalStudyMinutes,
      'chapterWeightages': _chapterWeightages.map((e) => e.toJson()).toList(),
      'twentyMarkTopicReference': _twentyMarkTopicReference,
      'learningStage': _learningStage,
      'taskQueueIndex': _taskQueueIndex,
      'taskRemainingSeconds': _taskRemainingSeconds,
      'taskSessionStarted': _taskSessionStarted,
      'taskOverlayEnabled': _taskOverlayEnabled,
      'taskDurations': _taskDurations,
      'totalTasks': totalTasks,
      'completedTaskIds': _completedTaskIds.toList(),
      'otherTasksBySubject': otherJson,
      'optionalTasks': _optionalTasks.map(_taskToJson).toList(),
      'optionalMilestones': _optionalMilestones,
      'customTaskCounter': _customTaskCounter,
      'generatedFlashcards': _flashcards.map((e) => e.toJson()).toList(),
      'flashcardIndex': _flashcardIndex,
      'flashcardFlipped': _flashcardFlipped,
      'flashcardCorrectCount': _flashcardCorrectCount,
      'flashcardResults': _flashcardResults
          .map((key, value) => MapEntry(key.toString(), value)),
      'flashcardUserAnswers': _flashcardUserAnswers
          .map((key, value) => MapEntry(key.toString(), value)),
      'generatedMockQuestions': _mockQuestions.map((e) => e.toJson()).toList(),
      'mockUserAnswers':
          _mockUserAnswers.map((key, value) => MapEntry(key.toString(), value)),
      'mockImageAnswers': _mockImageAnswers
          .map((key, value) => MapEntry(key.toString(), value.toJson())),
      'mockAwardedMarks': _mockAwardedMarks
          .map((key, value) => MapEntry(key.toString(), value)),
      'mockEvaluationNotes': _mockEvaluationNotes
          .map((key, value) => MapEntry(key.toString(), value)),
      'mockSubmitted': _mockSubmitted,
      'mockTotalAwarded': _mockTotalAwarded,
      'savedMockTests': _savedMockTests,
      'savedFlashcardSets': _savedFlashcardSets,
    });

    _journeyId = saveId;

    if (!mounted) {
      return;
    }

    if (markSaved) {
      setState(() {
        _isJourneySaved = true;
        _showJourneySetup = false;
      });
    }

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey saved.')),
      );
    }

    if (scrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }
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

  Future<void> _toggleTask(
    String taskId,
    bool isDone, {
    bool deferCompletionHandling = false,
  }) async {
    final allBefore = _allTasksForCurrentSubject();
    final wasComplete = _isJourneyComplete(allBefore, _completedTaskIds);

    if (mounted) {
      setState(() {
        if (isDone) {
          _completedTaskIds.add(taskId);
        } else {
          _completedTaskIds.remove(taskId);
        }
      });
    } else {
      if (isDone) {
        _completedTaskIds.add(taskId);
      } else {
        _completedTaskIds.remove(taskId);
      }
    }

    await _saveState();

    final allAfter = _allTasksForCurrentSubject();
    final nowComplete = _isJourneyComplete(allAfter, _completedTaskIds);
    if (!deferCompletionHandling && !wasComplete && nowComplete) {
      await _onAllTasksCompleted();
    }
  }

  Future<void> _changeSubject(String subjectKey) async {
    if (!_enabledSubjects.contains(subjectKey)) {
      return;
    }
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
        return const _SubjectBadgeData(
          title: 'Ace in Physics',
          icon: Icons.bolt_rounded,
          color: Color(0xFF1565C0),
        );
      case 'chemistry':
        return const _SubjectBadgeData(
          title: 'Ace in Chemistry',
          icon: Icons.science_rounded,
          color: Color(0xFF8D3F24),
        );
      case 'maths':
        return const _SubjectBadgeData(
          title: 'Ace in Maths',
          icon: Icons.functions_rounded,
          color: Color(0xFF3949AB),
        );
      case 'biology':
        return const _SubjectBadgeData(
          title: 'Ace in Biology',
          icon: Icons.eco_rounded,
          color: Color(0xFF2E7D32),
        );
      case 'optional':
        return const _SubjectBadgeData(
          title: 'Ace in Optional',
          icon: Icons.workspace_premium_rounded,
          color: Color(0xFF00695C),
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
      _taskTimer?.cancel();
      _examNameController.clear();
      _selectedSubject = 'physics';
      _completedTaskIds = <String>{};
      _otherTasksBySubject = <String, List<_JourneyTask>>{};
      _optionalTasks = <_JourneyTask>[];
      _optionalMilestones = <String>[];
      _customTaskCounter = 0;
      _journeyMarks = 20;
      _totalStudyMinutes = 60;
      _chapterWeightages = <_ChapterWeightage>[];
      _twentyMarkTopicReference = '';
      _learningStage = 'tasks';
      _taskQueueIndex = 0;
      _taskRemainingSeconds = 0;
      _taskSessionStarted = false;
      _taskOverlayEnabled = false;
      _taskDurations = <String, int>{};
      _flashcards = <_FlashcardItem>[];
      _flashcardIndex = 0;
      _flashcardFlipped = false;
      _flashcardCorrectCount = 0;
      _flashcardResults.clear();
      _flashcardUserAnswers.clear();
      _mockQuestions = <_MockQuestion>[];
      _mockUserAnswers.clear();
      _mockImageAnswers.clear();
      _mockAwardedMarks.clear();
      _mockEvaluationNotes.clear();
      _mockSubmitted = false;
      _mockTotalAwarded = 0;
      _savedMockTests = <Map<String, dynamic>>[];
      _savedFlashcardSets = <Map<String, dynamic>>[];
      _isJourneySaved = false;
      _showJourneySetup = true;
      _journeyId = null;
    });

    await widget.storeService.saveLearningJourneyState(null);
    JourneyTaskOverlayService.instance.hide();
  }

  @override
  void dispose() {
    _progressPersistTimer?.cancel();
    final tasks = _allTasksForCurrentSubject();
    final validIndex = _taskQueueIndex >= 0 && _taskQueueIndex < tasks.length;
    final shouldKeepRunning = _taskOverlayEnabled &&
        _isJourneySaved &&
        _learningStage == 'tasks' &&
        validIndex &&
        _taskSessionStarted;
    if (!shouldKeepRunning) {
      _taskTimer?.cancel();
    }
    if (_taskOverlayEnabled &&
        _isJourneySaved &&
        _learningStage == 'tasks' &&
        validIndex) {
      final current = tasks[_taskQueueIndex];
      JourneyTaskOverlayService.instance.showOrUpdate(
        enabled: true,
        running: _taskSessionStarted,
        taskTitle: current.label,
        remainingSeconds: _taskRemainingSeconds,
        taskIndex: _taskQueueIndex + 1,
        totalTasks: tasks.length,
      );
    }
    _scrollController.dispose();
    _examNameController.dispose();
    _flashcardAnswerController.dispose();
    super.dispose();
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
                    initialValue: selectedXp,
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

  void _initializeTaskQueue({bool startIfNeeded = true}) {
    final tasks = _allTasksForCurrentSubject();
    if (tasks.isEmpty) {
      _taskQueueIndex = 0;
      _taskRemainingSeconds = 0;
      _taskDurations = <String, int>{};
      return;
    }

    if (_taskDurations.isEmpty) {
      _taskDurations = _buildTaskDurations(tasks);
    }

    final nextPending = tasks.indexWhere(
      (task) => !_completedTaskIds.contains(task.id),
    );
    if (nextPending == -1) {
      _taskQueueIndex = tasks.length - 1;
      _taskRemainingSeconds = 0;
      return;
    }

    _taskQueueIndex = nextPending;
    _taskRemainingSeconds = _taskDurations[tasks[_taskQueueIndex].id] ?? 60;

    if (startIfNeeded) {
      _startTaskTimerForCurrentTask();
    }
    _syncTaskOverlay();
  }

  void _startTaskTimerForCurrentTask() {
    if (!_taskSessionStarted) {
      _taskTimer?.cancel();
      _syncTaskOverlay();
      return;
    }
    _taskTimer?.cancel();
    final tasks = _allTasksForCurrentSubject();
    if (tasks.isEmpty ||
        _taskQueueIndex < 0 ||
        _taskQueueIndex >= tasks.length) {
      _syncTaskOverlay();
      return;
    }

    if (_taskRemainingSeconds <= 0) {
      _taskRemainingSeconds = _taskDurations[tasks[_taskQueueIndex].id] ?? 60;
    }

    _taskTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_learningStage != 'tasks') {
        timer.cancel();
        return;
      }
      if (_taskRemainingSeconds <= 0) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _taskRemainingSeconds -= 1;
        });
      } else {
        _taskRemainingSeconds -= 1;
      }
      _syncTaskOverlay();
    });
    _syncTaskOverlay();
  }

  void _syncTaskOverlay() {
    final tasks = _allTasksForCurrentSubject();
    final canShow = _learningStage == 'tasks' &&
        _taskOverlayEnabled &&
        _isJourneySaved &&
        tasks.isNotEmpty &&
        _taskQueueIndex >= 0 &&
        _taskQueueIndex < tasks.length;
    if (!canShow) {
      JourneyTaskOverlayService.instance.hide();
      return;
    }

    final current = tasks[_taskQueueIndex];
    JourneyTaskOverlayService.instance.bindActions(
      onNext: () {
        if (!_taskSessionStarted) {
          return;
        }
        _completeCurrentTaskFromQueue();
      },
      onStart: () {
        if (mounted) {
          setState(() {
            _taskSessionStarted = true;
          });
        } else {
          _taskSessionStarted = true;
        }
        _startTaskTimerForCurrentTask();
        if (mounted) {
          _saveState();
        }
      },
      onPause: () {
        if (mounted) {
          setState(() {
            _taskSessionStarted = false;
          });
        } else {
          _taskSessionStarted = false;
        }
        _taskTimer?.cancel();
        _syncTaskOverlay();
        if (mounted) {
          _saveState();
        }
      },
    );

    JourneyTaskOverlayService.instance.showOrUpdate(
      enabled: _taskOverlayEnabled,
      running: _taskSessionStarted,
      taskTitle: current.label,
      remainingSeconds: _taskRemainingSeconds,
      taskIndex: _taskQueueIndex + 1,
      totalTasks: tasks.length,
    );
  }

  String _taskDifficulty(_JourneyTask task) {
    if (task.xp >= 25) {
      return 'Hard';
    }
    if (task.xp >= 15) {
      return 'Medium';
    }
    return 'Easy';
  }

  double _taskWeight(String difficulty) {
    switch (difficulty) {
      case 'Hard':
        return 1.8;
      case 'Medium':
        return 1.4;
      default:
        return 1.0;
    }
  }

  Map<String, int> _buildTaskDurations(List<_JourneyTask> tasks) {
    final totalSeconds =
        (_totalStudyMinutes <= 0 ? 60 : _totalStudyMinutes * 60);
    final weights = tasks
        .map((task) => _taskWeight(_taskDifficulty(task)))
        .toList(growable: false);
    final weightSum = weights.fold<double>(0, (sum, value) => sum + value);
    if (weightSum <= 0) {
      return <String, int>{};
    }

    final allocations = <String, int>{};
    var used = 0;
    for (var i = 0; i < tasks.length; i++) {
      final proportional = (totalSeconds * (weights[i] / weightSum)).round();
      final seconds = proportional < 30 ? 30 : proportional;
      allocations[tasks[i].id] = seconds;
      used += seconds;
    }

    if (allocations.isNotEmpty && used > 0 && used != totalSeconds) {
      final delta = totalSeconds - used;
      final lastTaskId = tasks.last.id;
      final adjusted = (allocations[lastTaskId] ?? 30) + delta;
      allocations[lastTaskId] = adjusted < 20 ? 20 : adjusted;
    }

    return allocations;
  }

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final mm = (safe ~/ 60).toString().padLeft(2, '0');
    final ss = (safe % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _completeCurrentTaskFromQueue() async {
    final tasks = _allTasksForCurrentSubject();
    if (tasks.isEmpty || _taskQueueIndex >= tasks.length) {
      return;
    }
    final currentTask = tasks[_taskQueueIndex];
    await _toggleTask(
      currentTask.id,
      true,
      deferCompletionHandling: true,
    );
    final nextPending = tasks.indexWhere(
      (task) => !_completedTaskIds.contains(task.id),
    );
    if (nextPending == -1) {
      await _onAllTasksCompleted();
      return;
    }
    if (mounted) {
      setState(() {
        _taskQueueIndex = nextPending;
        _taskRemainingSeconds = _taskDurations[tasks[_taskQueueIndex].id] ?? 60;
      });
    } else {
      _taskQueueIndex = nextPending;
      _taskRemainingSeconds = _taskDurations[tasks[_taskQueueIndex].id] ?? 60;
    }
    if (_taskSessionStarted) {
      _startTaskTimerForCurrentTask();
    }
    _syncTaskOverlay();
    await _saveState();
  }

  Future<void> _onAllTasksCompleted() async {
    _taskTimer?.cancel();
    JourneyTaskOverlayService.instance.hide();
    final template = _templates[_selectedSubject]!;
    if (mounted) {
      await _showCompletionAwardDialog(_selectedSubject, template.subjectLabel);
      setState(() {
        _learningStage = 'resources';
      });
    } else {
      _learningStage = 'resources';
    }
    await _saveState();
  }

  Future<void> _openSaveJourneyModalAndGenerate() async {
    final minutes =
        await _showJourneyTimeDialog(initialMinutes: _totalStudyMinutes);
    if (minutes == null) {
      return;
    }

    setState(() {
      _totalStudyMinutes = minutes;
      _journeyMarks = _journeyMarks <= 0 ? 20 : _journeyMarks;
      _totalStudyMinutes = _totalStudyMinutes <= 0 ? 60 : _totalStudyMinutes;
      _learningStage = 'tasks';
      _taskSessionStarted = false;
      _flashcards = <_FlashcardItem>[];
      _mockQuestions = <_MockQuestion>[];
      _flashcardIndex = 0;
      _flashcardFlipped = false;
      _flashcardCorrectCount = 0;
      _flashcardResults.clear();
      _flashcardUserAnswers.clear();
      _mockUserAnswers.clear();
      _mockAwardedMarks.clear();
      _mockSubmitted = false;
      _mockTotalAwarded = 0;
      _taskDurations = <String, int>{};
    });

    _initializeTaskQueue();
    await _saveState(markSaved: true, showFeedback: true, scrollToTop: true);
  }

  Future<int?> _showJourneyTimeDialog({required int initialMinutes}) async {
    final controller = TextEditingController(
      text: (initialMinutes <= 0 ? 60 : initialMinutes).toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Study Time'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Time for this chapter (minutes)',
              hintText: 'e.g. 90',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text.trim()) ?? 0;
                if (minutes <= 0) {
                  return;
                }
                Navigator.of(dialogContext).pop(minutes);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  bool get _supportsResourceAssist =>
      _selectedSubject == 'physics' || _selectedSubject == 'chemistry';

  bool _taskSuggestsNotes(_JourneyTask task) {
    final label = task.label.toLowerCase();
    return RegExp(
      r'read|watch|understand|explain|summary|summarise|learn|concept|definition|note|review',
    ).hasMatch(label);
  }

  bool _taskSuggestsWorksheets(_JourneyTask task) {
    final label = task.label.toLowerCase();
    return RegExp(
      r'solve|problem|practice|numerical|exam|question|past|quiz|test',
    ).hasMatch(label);
  }

  bool get _isDesktopResourceMode => Platform.isMacOS || Platform.isWindows;

  Future<void> _openDesktopResourceTabs({
    required bool includeNotes,
    required bool includeWorksheets,
  }) async {
    if (!mounted || !_isDesktopResourceMode) {
      return;
    }

    if (!includeNotes && !includeWorksheets) {
      return;
    }

    final payload = jsonEncode(<String, dynamic>{
      'includeNotes': includeNotes,
      'includeWorksheets': includeWorksheets,
      'initialTab': includeNotes ? 'notes' : 'worksheets',
      'themeMode':
          Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light',
    });

    try {
      final window = await DesktopMultiWindow.createWindow(payload);
      window
        ..setFrame(const Offset(160, 80) & const Size(675, 1200))
        ..setTitle('Referred Resources')
        ..center()
        ..show();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open a separate resource window.'),
        ),
      );
    }
  }

  Widget _buildPinnedResourceSection(_JourneyTask currentTask) {
    if (!_supportsResourceAssist) {
      return const SizedBox.shrink();
    }
    final hasNotes = _taskSuggestsNotes(currentTask);
    final hasWorksheets = _taskSuggestsWorksheets(currentTask);
    if (!hasNotes && !hasWorksheets) {
      return const SizedBox.shrink();
    }

    final useDesktopTabs = _isDesktopResourceMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.42),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pinned resources for this task',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            useDesktopTabs
                ? 'Desktop mode: open a separate resource window with tabs.'
                : 'Mobile mode: quick pinned actions stay visible here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (useDesktopTabs)
            FilledButton.icon(
              onPressed: () => _openDesktopResourceTabs(
                includeNotes: true,
                includeWorksheets: true,
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Referred Resources'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasNotes)
                  OutlinedButton.icon(
                    onPressed: _openNotesLibrary,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Refer Notes'),
                  ),
                if (hasNotes)
                  FilledButton.tonalIcon(
                    onPressed: _openNotesStudio,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Create Notes'),
                  ),
                if (hasWorksheets)
                  OutlinedButton.icon(
                    onPressed: _openWorksheetLibrary,
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('Worksheet Library'),
                  ),
                if (hasWorksheets)
                  FilledButton.tonalIcon(
                    onPressed: _openWorksheetStudio,
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Create Worksheet'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openWorksheetLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Worksheet Library')),
          body: WorksheetsLibraryScreen(storeService: widget.storeService),
        ),
      ),
    );
  }

  Future<void> _openWorksheetStudio() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Create Worksheet')),
          body: WorksheetScreen(storeService: widget.storeService),
        ),
      ),
    );
  }

  Future<void> _openNotesLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Notes Library')),
          body: NotesLibraryScreen(storeService: widget.storeService),
        ),
      ),
    );
  }

  Future<void> _openNotesStudio() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Create Notes')),
          body: NotesScreen(storeService: widget.storeService),
        ),
      ),
    );
  }

  Future<void> _generateJourneyAssetsWithPopup() async {
    if (!mounted || _generatingJourneyAssets) {
      return;
    }

    var dialogShown = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        dialogShown = true;
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Generating material')),
            ],
          ),
        );
      },
    );

    try {
      await _generateJourneyAssets();
    } finally {
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  String _primaryReferenceTopic() {
    if (_journeyMarks == 20 && _twentyMarkTopicReference.trim().isNotEmpty) {
      return _twentyMarkTopicReference.trim();
    }
    final exam = _examNameController.text.trim();
    if (exam.isNotEmpty) {
      return exam;
    }
    return _templates[_selectedSubject]!.subjectLabel;
  }

  Future<void> _generateJourneyAssets() async {
    if (_generatingJourneyAssets) {
      return;
    }
    setState(() {
      _generatingJourneyAssets = true;
    });
    try {
      final generatedMockQuestions = await _generateMockTest();
      if (!mounted) {
        return;
      }
      setState(() {
        _mockQuestions = generatedMockQuestions;
      });
      await _saveState();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingJourneyAssets = false;
        });
      }
    }
  }

  String _buildChaptersSummary() {
    if (_journeyMarks == 20 && _twentyMarkTopicReference.trim().isNotEmpty) {
      return _twentyMarkTopicReference.trim();
    }
    if (_chapterWeightages.isEmpty) {
      final topic = _examNameController.text.trim();
      return topic.isEmpty ? _templates[_selectedSubject]!.subjectLabel : topic;
    }
    return _chapterWeightages
        .map((chapter) => '${chapter.chapter}: ${chapter.marks} marks')
        .join(', ');
  }

  Future<List<_FlashcardItem>> _generateFlashcards() async {
    final cardCount = _journeyMarks == 70 ? 25 : 15;
    final prompt =
        'Generate $cardCount fill-in-the-blank flashcards for the topic: ${_primaryReferenceTopic()}. '
        'Use this chapter/topic reference for content scope: ${_buildChaptersSummary()}. '
        'Each flashcard must have: '
        '"front" (fill-in-the-blank sentence with exactly one blank using ____ , max 14 words) and '
        '"back" (ONLY final answer in 1-2 words. No explanation, no full sentence). '
        'Distribute cards as follows: ${_buildChaptersSummary()}. '
        'Return strictly JSON array: [{"front":"...","back":"..."}] with no extra text.';
    final raw = await _chatService.sendMessage(prompt);
    final payload = _extractJsonPayload(raw);
    final decoded = _decodeJsonLenient(payload);
    var cards = _extractFlashcardsFromDecoded(decoded);
    if (cards.length < 2) {
      cards = _extractFlashcardsFromText(raw);
    }
    if (cards.length > cardCount) {
      cards = cards.take(cardCount).toList();
    }
    cards = cards.map(_sanitizeFlashcardItem).toList();
    if (cards.isEmpty) {
      throw Exception('No flashcards generated.');
    }
    return cards;
  }

  Future<List<_MockQuestion>> _generateMockTest() async {
    late final String prompt;
    if (_journeyMarks == 20) {
      prompt =
          'Generate a 20-mark mock test covering the following chapter/topic reference: ${_primaryReferenceTopic()}. '
          'Include a mix of MCQs (5x1 mark), short answers (2x2 marks), medium answers (2x3 marks), and long answers (1x5 marks), with numericals where applicable. '
          'For each question include: question, chapter, section, type (mcq/short/long/numerical), marks, difficulty, options(for mcq), correct answer, and keyword list for evaluation. '
          'Answer format rule: for mcq/short/long use ONLY 1-2 words in correct answer. For numerical use ONLY final numeric value with symbol/unit (example: 4×10^3 N/C). '
          'Return strictly as JSON object: {"questions": [...]} with no extra text.';
    } else {
      prompt =
          'Generate a 70-mark mock test covering the following chapters with their weightages: ${_buildChaptersSummary()}. '
          'Include a mix of MCQs (16x1 mark), short answers 5x(2 marks)7x(3 marks), long answers 3x(5 marks)and 2x (4 marks case study), and numericals where applicable. '
          'For each question include: chapter, section, question, type, marks, difficulty, options(for mcq), correct answer, and keyword list for evaluation. '
          'Answer format rule: for mcq/short/long use ONLY 1-2 words in correct answer. For numerical use ONLY final numeric value with symbol/unit (example: 4×10^3 N/C). '
          'Return strictly as JSON object: {"questions": [...]} with no extra text.';
    }
    final raw = await _chatService.sendMessage(prompt);
    final payload = _extractJsonPayload(raw);
    List<_MockQuestion> questions = <_MockQuestion>[];
    try {
      final decoded = _decodeJsonLenient(payload);
      List<dynamic> questionsRaw = <dynamic>[];
      if (decoded is Map<String, dynamic>) {
        questionsRaw = decoded['questions'] as List<dynamic>? ?? <dynamic>[];
      } else if (decoded is List<dynamic>) {
        questionsRaw = decoded;
      }
      questions = questionsRaw
          .whereType<Map<String, dynamic>>()
          .map(_MockQuestion.fromJson)
          .toList();
    } catch (_) {
      questions = _extractMockQuestionsFromText(payload);
    }
    if (questions.isEmpty) {
      questions = _extractMockQuestionsFromText(raw);
    }
    if (questions.isEmpty) {
      throw Exception('No mock questions generated.');
    }
    final withAnswers = await _ensureMockAnswers(questions);
    return withAnswers.map(_sanitizeMockQuestionAnswer).toList();
  }

  _FlashcardItem _sanitizeFlashcardItem(_FlashcardItem item) {
    final answer = _extractFlashcardExpectedAnswer(item.back);
    final cleaned = _toOneOrTwoWords(answer);
    return _FlashcardItem(
      front: item.front,
      back: cleaned.isEmpty ? item.back.trim() : cleaned,
      keywords: item.keywords,
    );
  }

  _MockQuestion _sanitizeMockQuestionAnswer(_MockQuestion question) {
    final raw = question.correctAnswer.trim();
    if (raw.isEmpty) {
      return question;
    }

    if (question.type == 'numerical') {
      final compact = _extractNumericAnswerWithOptionalUnit(raw);
      return question.copyWith(
        correctAnswer: compact.isEmpty ? raw : compact,
      );
    }

    final short = _toOneOrTwoWords(raw);
    return question.copyWith(
      correctAnswer: short.isEmpty ? raw : short,
      keywords: question.keywords.isEmpty
          ? _keywordsFromAnswer(short.isEmpty ? raw : short)
          : question.keywords,
    );
  }

  String _toOneOrTwoWords(String text) {
    final tokens =
        _normalizeText(text).split(' ').where((e) => e.isNotEmpty).toList();
    if (tokens.isEmpty) {
      return '';
    }
    if (tokens.length == 1) {
      return tokens.first;
    }
    return '${tokens[0]} ${tokens[1]}';
  }

  String _extractNumericAnswerWithOptionalUnit(String text) {
    var normalized = text
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll('−', '-')
        .replaceAll(' ', ' ')
        .trim();

    final sciMatch = RegExp(r'([+-]?\d*\.?\d+)\s*\*?\s*10\^\s*([+-]?\d+)')
        .firstMatch(normalized);
    if (sciMatch != null) {
      final numberPart = '${sciMatch.group(1)}×10^${sciMatch.group(2)}';
      final tail = normalized.substring(sciMatch.end).trim();
      return tail.isEmpty ? numberPart : '$numberPart $tail';
    }

    final numberMatch =
        RegExp(r'([+-]?\d*\.?\d+(?:e[+-]?\d+)?)').firstMatch(normalized);
    if (numberMatch == null) {
      return normalized;
    }
    final numberPart = numberMatch.group(1)!;
    final tail = normalized.substring(numberMatch.end).trim();
    return tail.isEmpty ? numberPart : '$numberPart $tail';
  }

  Future<List<_MockQuestion>> _ensureMockAnswers(
      List<_MockQuestion> questions) async {
    final missing = <int>[];
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].correctAnswer.trim().isEmpty) {
        missing.add(i);
      }
    }
    if (missing.isEmpty) {
      return questions;
    }

    final compact = missing
        .map((i) => {
              'index': i,
              'question': questions[i].text,
              'type': questions[i].type,
              'marks': questions[i].marks,
              'options': questions[i].options,
            })
        .toList();
    final prompt =
        'Fill missing answer keys for these questions. Return ONLY JSON array with items as '
        '{"index": <number>, "correctAnswer": "...", "keywords": ["...", "..."]}. '
        'Questions: ${jsonEncode(compact)}';

    try {
      final raw = await _chatService.sendMessage(prompt);
      final payload = _extractJsonPayload(raw);
      final decoded = _decodeJsonLenient(payload);
      if (decoded is! List<dynamic>) {
        return questions;
      }

      final updates = <int, Map<String, dynamic>>{};
      for (final row in decoded.whereType<Map<String, dynamic>>()) {
        final index = int.tryParse(row['index']?.toString() ?? '');
        if (index == null) {
          continue;
        }
        updates[index] = row;
      }

      final next = <_MockQuestion>[];
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final patch = updates[i];
        if (patch == null || q.correctAnswer.trim().isNotEmpty) {
          next.add(q);
          continue;
        }
        final correctedAnswer = patch['correctAnswer']?.toString().trim() ?? '';
        final patchedKeywords =
            (patch['keywords'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList();
        next.add(
          q.copyWith(
            correctAnswer: correctedAnswer,
            keywords: patchedKeywords.isEmpty
                ? _keywordsFromAnswer(correctedAnswer)
                : patchedKeywords,
          ),
        );
      }
      return next;
    } catch (_) {
      return questions;
    }
  }

  String _extractJsonPayload(String raw) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true)
        .firstMatch(raw);
    if (fenced != null) {
      return fenced.group(1)!.trim();
    }
    final firstBracket = raw.indexOf('[');
    final lastBracket = raw.lastIndexOf(']');
    if (firstBracket != -1 && lastBracket > firstBracket) {
      return raw.substring(firstBracket, lastBracket + 1).trim();
    }
    final firstBrace = raw.indexOf('{');
    final lastBrace = raw.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      return raw.substring(firstBrace, lastBrace + 1).trim();
    }
    throw Exception('Unable to find JSON in response.');
  }

  dynamic _decodeJsonLenient(String payload) {
    try {
      return jsonDecode(payload);
    } catch (_) {
      final repaired = _repairCommonJsonIssues(payload);
      return jsonDecode(repaired);
    }
  }

  String _repairCommonJsonIssues(String input) {
    var value = input.trim();

    // Common malformed shape from LLMs: ["front":"...","back":"..."]
    // where object braces are missing inside an array.
    if (value.startsWith('[') &&
        value.endsWith(']') &&
        value.contains('"front"') &&
        value.contains('"back"') &&
        !value.contains('{')) {
      value = value.replaceFirst('[', '[{');
      final lastBracket = value.lastIndexOf(']');
      value = '${value.substring(0, lastBracket)}}]';
    }

    return value;
  }

  List<_FlashcardItem> _extractFlashcardsFromDecoded(dynamic decoded) {
    if (decoded is List<dynamic>) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_FlashcardItem.fromJson)
          .where((item) =>
              item.front.trim().isNotEmpty && item.back.trim().isNotEmpty)
          .toList();
    }

    // Fallback for flat map payloads.
    if (decoded is Map<String, dynamic>) {
      final maybeList = decoded['flashcards'] ?? decoded['cards'];
      if (maybeList is List<dynamic>) {
        return maybeList
            .whereType<Map<String, dynamic>>()
            .map(_FlashcardItem.fromJson)
            .where((item) =>
                item.front.trim().isNotEmpty && item.back.trim().isNotEmpty)
            .toList();
      }
    }

    return <_FlashcardItem>[];
  }

  List<_FlashcardItem> _extractFlashcardsFromText(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final frontMatches = RegExp(r'"front"\s*:\s*"((?:\\.|[^"\\])*)"')
        .allMatches(normalized)
        .toList();
    final backMatches = RegExp(r'"back"\s*:\s*"((?:\\.|[^"\\])*)"')
        .allMatches(normalized)
        .toList();
    if (frontMatches.isEmpty || backMatches.isEmpty) {
      return <_FlashcardItem>[];
    }
    final count = frontMatches.length < backMatches.length
        ? frontMatches.length
        : backMatches.length;
    final cards = <_FlashcardItem>[];
    for (var i = 0; i < count; i++) {
      final front = (frontMatches[i].group(1) ?? '')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .trim();
      final back = (backMatches[i].group(1) ?? '')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .trim();
      if (front.isEmpty || back.isEmpty) {
        continue;
      }
      cards.add(_FlashcardItem(front: front, back: back));
    }
    return cards;
  }

  List<_MockQuestion> _extractMockQuestionsFromText(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final keyRegex = RegExp(
      r'"(?:questionText|question_text|question text|question)"\s*:',
    );
    final matches = keyRegex.allMatches(normalized).toList();
    if (matches.isEmpty) {
      return <_MockQuestion>[];
    }

    final questions = <_MockQuestion>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end =
          i + 1 < matches.length ? matches[i + 1].start : normalized.length;
      final chunk = normalized.substring(start, end);

      final questionText = _extractQuotedValue(chunk, 'questionText') ??
          _extractQuotedValue(chunk, 'question_text') ??
          _extractQuotedValue(chunk, 'question text') ??
          _extractQuotedValue(chunk, 'question') ??
          '';
      if (questionText.trim().isEmpty) {
        continue;
      }

      final chapter = _extractQuotedValue(chunk, 'chapter') ?? 'General';
      final section = _extractQuotedValue(chunk, 'section') ?? 'Section';
      final type =
          (_extractQuotedValue(chunk, 'type') ?? 'short').toLowerCase();
      final difficulty = _extractQuotedValue(chunk, 'difficulty') ?? 'Medium';
      final correctAnswer = _extractQuotedValue(chunk, 'correctAnswer') ??
          _extractQuotedValue(chunk, 'modelAnswer') ??
          _extractQuotedValue(chunk, 'expectedAnswer') ??
          _extractQuotedValue(chunk, 'sampleAnswer') ??
          _extractQuotedValue(chunk, 'solution') ??
          _extractQuotedValue(chunk, 'answer') ??
          '';
      final marks = _extractIntValue(chunk, 'marks') ?? 1;
      final options = _extractStringArray(chunk, 'options');
      var keywords = _extractStringArray(chunk, 'keywords');
      if (keywords.isEmpty && correctAnswer.trim().isNotEmpty) {
        keywords = _keywordsFromAnswer(correctAnswer);
      }

      questions.add(
        _MockQuestion(
          chapter: chapter,
          section: section,
          text: questionText,
          type: type,
          marks: marks,
          difficulty: difficulty,
          correctAnswer: correctAnswer,
          keywords: keywords,
          options: options,
          tolerance: _extractDoubleValue(chunk, 'tolerance'),
        ),
      );
    }

    return questions;
  }

  String? _extractQuotedValue(String source, String key) {
    final match =
        RegExp('"$key"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"').firstMatch(source);
    if (match == null) {
      return null;
    }
    return match.group(1)?.replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
  }

  int? _extractIntValue(String source, String key) {
    final match = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(source);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  double? _extractDoubleValue(String source, String key) {
    final match =
        RegExp('"$key"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)').firstMatch(source);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  List<String> _extractStringArray(String source, String key) {
    final match = RegExp('"$key"\\s*:\\s*\\[([^\\]]*)\\]').firstMatch(source);
    if (match == null) {
      return <String>[];
    }
    final raw = match.group(1) ?? '';
    return RegExp('"((?:\\\\.|[^"\\\\])*)"')
        .allMatches(raw)
        .map((m) => (m.group(1) ?? '').replaceAll(r'\"', '"'))
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }

  bool _keywordMatch(String userText, List<String> keywords,
      {double threshold = 0.6}) {
    if (keywords.isEmpty) {
      return userText.trim().isNotEmpty;
    }
    final normalizedUser = _normalizeText(userText);
    if (normalizedUser.isEmpty) {
      return false;
    }
    var matched = 0;
    for (final keyword in keywords) {
      final normalizedKeyword = _normalizeText(keyword);
      if (normalizedKeyword.isEmpty) {
        continue;
      }
      if (normalizedUser.contains(normalizedKeyword)) {
        matched += 1;
      }
    }
    return (matched / keywords.length) >= threshold;
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _keywordsFromAnswer(String text) {
    final words = _normalizeText(text)
        .split(' ')
        .where((w) => w.length > 3)
        .toSet()
        .toList();
    if (words.length <= 8) {
      return words;
    }
    return words.take(8).toList();
  }

  void _evaluateFlashcardAnswer() {
    if (_flashcards.isEmpty || _flashcardIndex >= _flashcards.length) {
      return;
    }
    final card = _flashcards[_flashcardIndex];
    final userAnswer = _flashcardAnswerController.text.trim();
    final expected = _extractFlashcardExpectedAnswer(card.back);
    final keywords = card.keywords.isEmpty
        ? _keywordsFromAnswer(expected.isEmpty ? card.back : expected)
        : card.keywords;
    final isCorrect = _keywordMatch(userAnswer, keywords, threshold: 0.5);
    setState(() {
      _flashcardResults[_flashcardIndex] = isCorrect;
      _flashcardUserAnswers[_flashcardIndex] = userAnswer;
      _flashcardFlipped = true;
      _flashcardCorrectCount = _flashcardResults.values.where((v) => v).length;
    });
  }

  Future<void> _nextFlashcard() async {
    if (_flashcardIndex + 1 >= _flashcards.length) {
      setState(() {
        _learningStage = 'mock_test';
      });
      _flashcardAnswerController.clear();
      await _saveState();
      return;
    }
    setState(() {
      _flashcardIndex += 1;
      _flashcardFlipped = false;
    });
    _flashcardAnswerController.clear();
    _scheduleProgressPersist();
  }

  void _scheduleProgressPersist() {
    _progressPersistTimer?.cancel();
    _progressPersistTimer = Timer(const Duration(milliseconds: 450), () {
      _saveState();
    });
  }

  String _extractFlashcardExpectedAnswer(String back) {
    final explicit = RegExp(r'answer\s*:\s*([^\n\.]+)', caseSensitive: false)
        .firstMatch(back);
    if (explicit != null) {
      return explicit.group(1)?.trim() ?? '';
    }
    final firstSentence = back.split(RegExp(r'[\n\.]')).first.trim();
    return firstSentence;
  }

  Future<void> _evaluateMockTest() async {
    if (_mockQuestions.isEmpty) {
      return;
    }
    try {
      await _ensureAnswersForEvaluation();
      final awarded = <int, double>{};
      final notes = <int, String>{};
      var total = 0.0;
      for (var index = 0; index < _mockQuestions.length; index++) {
        final question = _mockQuestions[index];
        final userValue = _mockUserAnswers[index]?.toString() ?? '';
        final marks = question.marks.toDouble();
        double score = 0;
        if (question.type == 'mcq') {
          score = _normalizeText(userValue) ==
                  _normalizeText(question.correctAnswer)
              ? marks
              : 0;
        } else if (question.type == 'numerical') {
          final userNumber = _parseFlexibleNumber(userValue.trim());
          final correctNumber =
              _parseFlexibleNumber(question.correctAnswer.trim());
          if (userNumber != null && correctNumber != null) {
            final tolerance = question.tolerance ??
                (0.01 * (correctNumber.abs() < 1 ? 1 : correctNumber.abs()));
            if ((userNumber - correctNumber).abs() <= tolerance) {
              score = marks;
            }
          }
        } else {
          final imageAnswer = _mockImageAnswers[index];
          if (imageAnswer != null && userValue.trim().isEmpty) {
            final aiResult =
                await _evaluateTheoryFromImage(question, imageAnswer, marks);
            score = aiResult.awarded.clamp(0, marks);
            if (aiResult.note.trim().isNotEmpty) {
              notes[index] = aiResult.note;
            }
          } else {
            final keywords = question.keywords.isEmpty
                ? _keywordsFromAnswer(question.correctAnswer)
                : question.keywords;
            var matched = 0;
            final normalizedUser = _normalizeText(userValue);
            for (final keyword in keywords) {
              final normalizedKeyword = _normalizeText(keyword);
              if (normalizedKeyword.isNotEmpty &&
                  normalizedUser.contains(normalizedKeyword)) {
                matched += 1;
              }
            }
            if (keywords.isNotEmpty) {
              final ratio = matched / keywords.length;
              score = marks * ratio;
            }
          }
        }
        awarded[index] = score;
        total += score;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _mockAwardedMarks
          ..clear()
          ..addAll(awarded);
        _mockEvaluationNotes
          ..clear()
          ..addAll(notes);
        _mockTotalAwarded = total;
        _mockSubmitted = true;
      });
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _ensureAnswersForEvaluation() async {
    final missingIndexes = <int>[];
    for (var i = 0; i < _mockQuestions.length; i++) {
      if (_mockQuestions[i].correctAnswer.trim().isEmpty) {
        missingIndexes.add(i);
      }
    }
    if (missingIndexes.isEmpty) {
      return;
    }

    final updated = List<_MockQuestion>.from(_mockQuestions);
    for (final index in missingIndexes) {
      final generated = await _generateAnswerForSingleQuestion(updated[index]);
      updated[index] = generated;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _mockQuestions = updated;
    });
    await _saveState();
  }

  Future<_MockQuestion> _generateAnswerForSingleQuestion(
      _MockQuestion question) async {
    final prompt =
        'Provide answer key for this question. Return ONLY JSON object '
        '{"correctAnswer":"...", "keywords":["...","..."]}. '
        'Question: ${question.text}. '
        'Type: ${question.type}. Marks: ${question.marks}. '
        'Answer format rule: if type is numerical, return only final numeric value with symbol/unit. '
        'Otherwise return only 1-2 words as correctAnswer. '
        'Options (if any): ${question.options.join(' | ')}';
    try {
      final raw = await _chatService.sendMessage(prompt);
      final payload = _extractJsonPayload(raw);
      final decoded = _decodeJsonLenient(payload);
      if (decoded is Map<String, dynamic>) {
        final answer = (decoded['correctAnswer'] ?? decoded['answer'] ?? '')
            .toString()
            .trim();
        final keys =
            (decoded['keywords'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList();
        if (answer.isNotEmpty) {
          return question.copyWith(
            correctAnswer: answer,
            keywords: keys.isEmpty ? _keywordsFromAnswer(answer) : keys,
          );
        }
      }
    } catch (_) {
      // Fall through.
    }
    return question;
  }

  double? _parseFlexibleNumber(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    var value = raw
        .toLowerCase()
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll(' ', '')
        .replaceAll(',', '');

    final direct = double.tryParse(value);
    if (direct != null) {
      return direct;
    }

    final sci = RegExp(r'([+-]?\d*\.?\d+)\*?10\^([+-]?\d+)').firstMatch(value);
    if (sci != null) {
      final base = double.tryParse(sci.group(1)!);
      final exp = int.tryParse(sci.group(2)!);
      if (base != null && exp != null) {
        return base * _pow10(exp);
      }
    }

    final numberOnly =
        RegExp(r'([+-]?\d*\.?\d+(?:e[+-]?\d+)?)').firstMatch(value);
    if (numberOnly != null) {
      return double.tryParse(numberOnly.group(1)!);
    }

    return null;
  }

  double _pow10(int exp) {
    var result = 1.0;
    if (exp >= 0) {
      for (var i = 0; i < exp; i++) {
        result *= 10;
      }
      return result;
    }
    for (var i = 0; i < -exp; i++) {
      result /= 10;
    }
    return result;
  }

  Future<void> _pickTheoryAnswerImage(int index) async {
    final files = await _fileSelectionService.pickFiles(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
      allowMultiple: false,
      dialogLabel: 'Theory Answer Image',
    );
    if (!mounted || files.isEmpty) {
      return;
    }
    final item = files.first;
    setState(() {
      _mockImageAnswers[index] = _ImageAnswerAttachment(
        name: item.name,
        mimeType: _mimeTypeForImage(item.name),
        base64Data: base64Encode(item.bytes),
      );
    });
    _scheduleProgressPersist();
  }

  String _mimeTypeForImage(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lower.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }

  Future<_TheoryEvalResult> _evaluateTheoryFromImage(
    _MockQuestion question,
    _ImageAnswerAttachment image,
    double maxMarks,
  ) async {
    final keywords = question.keywords.isEmpty
        ? _keywordsFromAnswer(question.correctAnswer)
        : question.keywords;
    try {
      final extracted = await _extractTextFromImageOffline(image);
      final normalized = _normalizeText(extracted);
      if (normalized.isEmpty) {
        return const _TheoryEvalResult(
          awarded: 0,
          note: 'Could not read text from image.',
        );
      }
      var matched = 0;
      for (final keyword in keywords) {
        final normalizedKeyword = _normalizeText(keyword);
        if (normalizedKeyword.isNotEmpty &&
            normalized.contains(normalizedKeyword)) {
          matched += 1;
        }
      }
      final ratio = keywords.isEmpty ? 0.0 : (matched / keywords.length);
      final awarded = maxMarks * ratio;
      return _TheoryEvalResult(
        awarded: awarded,
        note:
            'OCR extracted answer used for offline evaluation. Keywords matched: $matched/${keywords.length}.',
      );
    } catch (_) {
      return const _TheoryEvalResult(
        awarded: 0,
        note:
            'Image auto-evaluation is unavailable. Please type your answer text for evaluation.',
      );
    }
  }

  Future<String> _extractTextFromImageOffline(
      _ImageAnswerAttachment image) async {
    // Fallback when ML Kit is not bundled in the app.
    // Keeping this async contract avoids touching other evaluation paths.
    final bytes = base64Decode(image.base64Data);
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/theory_eval_${DateTime.now().microsecondsSinceEpoch}_${image.name}';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    return '';
  }

  Future<void> _saveCurrentFlashcards() async {
    if (_flashcards.isEmpty) {
      return;
    }
    final topic = _examNameController.text.trim().isEmpty
        ? _templates[_selectedSubject]!.subjectLabel
        : _examNameController.text.trim();
    final now = DateTime.now();
    final item = <String, dynamic>{
      'id': 'flash_${now.microsecondsSinceEpoch}',
      'topic': topic,
      'date': now.toIso8601String(),
      'cards': _flashcards.map((e) => e.toJson()).toList(),
      'score': _flashcardCorrectCount,
      'total': _flashcards.length,
    };
    setState(() {
      _savedFlashcardSets.insert(0, item);
    });
    await _saveState(showFeedback: true);
  }

  Future<void> _saveCurrentMockTest() async {
    if (_mockQuestions.isEmpty || !_mockSubmitted) {
      return;
    }
    final topic = _examNameController.text.trim().isEmpty
        ? _templates[_selectedSubject]!.subjectLabel
        : _examNameController.text.trim();
    final now = DateTime.now();
    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < _mockQuestions.length; i++) {
      answers.add({
        'question': _mockQuestions[i].toJson(),
        'userAnswer': _mockUserAnswers[i]?.toString() ?? '',
        'awarded': _mockAwardedMarks[i] ?? 0,
        'evaluationNote': _mockEvaluationNotes[i] ?? '',
        'imageAnswerName': _mockImageAnswers[i]?.name ?? '',
      });
    }
    final item = <String, dynamic>{
      'id': 'mock_${now.microsecondsSinceEpoch}',
      'topic': topic,
      'date': now.toIso8601String(),
      'marks': _journeyMarks,
      'score': _mockTotalAwarded,
      'answers': answers,
    };
    setState(() {
      _savedMockTests.insert(0, item);
    });
    await _saveState(showFeedback: true);
  }

  Future<void> _askTutorForQuestion(_MockQuestion question) async {
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Asking tutor...')),
          ],
        ),
      ),
    );

    String answer;
    try {
      final prompt =
          'You are a school tutor. Solve and explain this question clearly. '
          'Question: ${question.text}. '
          'Type: ${question.type}, Marks: ${question.marks}, Difficulty: ${question.difficulty}. '
          'Give step-by-step where needed and finish with a short final answer.';
      answer = await _chatService.sendMessage(prompt);
    } catch (e) {
      answer = 'Could not get tutor answer right now: $e';
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tutor Answer'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(child: Text(answer)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildStagedJourneyWidgets(List<_JourneyTask> allTasks) {
    final widgets = <Widget>[];
    widgets.add(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Journey plan: Focus $_totalStudyMinutes minutes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stage: ${_learningStage == 'tasks' ? 'Tasks' : 'Resources'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
    widgets.add(const SizedBox(height: 10));

    if (_learningStage == 'tasks') {
      final hasTasks = allTasks.isNotEmpty;
      final safeIndex = _taskQueueIndex >= allTasks.length
          ? (allTasks.isEmpty ? 0 : allTasks.length - 1)
          : _taskQueueIndex;
      final currentTask = hasTasks ? allTasks[safeIndex] : null;
      final ratio = allTasks.isEmpty
          ? 0.0
          : (_completedTaskIds.length / allTasks.length).clamp(0.0, 1.0);
      final remainingLabel = _formatDuration(_taskRemainingSeconds);
      widgets.add(
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: currentTask == null
                ? const Text('No tasks in this journey yet.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.92),
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.72),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MAIN TARGET',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentTask.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.3,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Task ${safeIndex + 1} of ${allTasks.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.35),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              remainingLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const Spacer(),
                            Chip(label: Text(_taskDifficulty(currentTask))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _taskSessionStarted = true;
                              });
                              _startTaskTimerForCurrentTask();
                              _syncTaskOverlay();
                              _saveState();
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Session'),
                          ),
                          OutlinedButton.icon(
                            onPressed: !_taskSessionStarted
                                ? null
                                : () {
                                    setState(() {
                                      _taskSessionStarted = false;
                                    });
                                    _taskTimer?.cancel();
                                    _syncTaskOverlay();
                                    _saveState();
                                  },
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pause Session'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Progress ${(ratio * 100).round()}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '${_completedTaskIds.length}/${allTasks.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: ratio),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show floating task timer'),
                        subtitle:
                            const Text('Draggable timer across app screens'),
                        value: _taskOverlayEnabled,
                        onChanged: (value) {
                          setState(() {
                            _taskOverlayEnabled = value;
                          });
                          _syncTaskOverlay();
                          _saveState();
                        },
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: !_taskSessionStarted
                            ? null
                            : () => _completeCurrentTaskFromQueue(),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Complete & Next Task'),
                      ),
                      const SizedBox(height: 8),
                      _buildPinnedResourceSection(currentTask),
                    ],
                  ),
          ),
        ),
      );
    } else {
      widgets.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks complete. Continue with learning resources.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (_supportsResourceAssist) ...[
                  if (_isDesktopResourceMode)
                    FilledButton.icon(
                      onPressed: () => _openDesktopResourceTabs(
                        includeNotes: true,
                        includeWorksheets: true,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open Notes/Worksheets Window'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openWorksheetLibrary,
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('Open Worksheet Library'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _openWorksheetStudio,
                          icon: const Icon(Icons.add_task_outlined),
                          label: const Text('Create Worksheet'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openNotesLibrary,
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Open Notes Library'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _openNotesStudio,
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Create Notes'),
                        ),
                      ],
                    ),
                ] else
                  Text(
                    'Resource shortcuts are enabled for Physics and Chemistry only.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildMockQuestionInput(int index) {
    final question = _mockQuestions[index];
    final marks = question.marks;
    final awarded = _mockAwardedMarks[index] ?? 0;
    final ratio = marks <= 0 ? 0.0 : (awarded / marks);
    final scoreColor = _scoreColor(ratio);
    final value = _mockUserAnswers[index]?.toString() ?? '';
    final attachedImage = _mockImageAnswers[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q${index + 1}. ${question.text}'),
            const SizedBox(height: 6),
            Text('${question.chapter} • ${question.difficulty} • $marks marks'),
            const SizedBox(height: 8),
            if (!_mockSubmitted)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _askTutorForQuestion(question),
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Ask Tutor'),
                ),
              ),
            if (question.type == 'mcq')
              ...question.options.map((option) {
                return RadioListTile<String>(
                  value: option,
                  groupValue: value,
                  onChanged: _mockSubmitted
                      ? null
                      : (selected) {
                          if (selected == null) {
                            return;
                          }
                          setState(() {
                            _mockUserAnswers[index] = selected;
                          });
                          _scheduleProgressPersist();
                        },
                  title: Text(option),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              })
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    enabled: !_mockSubmitted,
                    minLines: question.type == 'long' ? 3 : 1,
                    maxLines: question.type == 'long' ? 5 : 2,
                    keyboardType: question.type == 'numerical'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    controller: TextEditingController(text: value),
                    onChanged: (text) {
                      _mockUserAnswers[index] = text;
                      _scheduleProgressPersist();
                    },
                    decoration: InputDecoration(
                      labelText: question.type == 'numerical'
                          ? 'Enter final value'
                          : 'Type your answer',
                    ),
                  ),
                  if (!_mockSubmitted &&
                      question.type != 'mcq' &&
                      question.type != 'numerical') ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickTheoryAnswerImage(index),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Attach Answer Photo'),
                        ),
                        if (attachedImage != null)
                          Chip(label: Text(attachedImage.name)),
                      ],
                    ),
                  ],
                ],
              ),
            if (_mockSubmitted) ...[
              const SizedBox(height: 8),
              Text(
                'Correct answer: ${question.correctAnswer}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Your score: ${awarded.toStringAsFixed(1)} / $marks',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
              ),
              if ((_mockEvaluationNotes[index] ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _mockEvaluationNotes[index]!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double ratio) {
    if (ratio <= 0) {
      return Colors.red;
    }
    if (ratio <= 0.6) {
      return Colors.amber.shade700;
    }
    return Colors.green;
  }

  Widget _buildSavedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            if (_savedMockTests.isEmpty)
              const Text('No saved mock tests yet.')
            else
              ..._savedMockTests.map((item) {
                final date = DateTime.tryParse(item['date']?.toString() ?? '');
                final topic = item['topic']?.toString() ?? 'Mock Test';
                final score =
                    double.tryParse(item['score']?.toString() ?? '') ?? 0;
                final marks = int.tryParse(item['marks']?.toString() ?? '') ??
                    _journeyMarks;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(topic),
                  subtitle: Text(
                    '${date?.toLocal().toString().split('.').first ?? '-'} • ${score.toStringAsFixed(1)}/$marks',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _showSavedMockAnswerSheet(item),
                    child: const Text('View'),
                  ),
                  onTap: () => _showSavedMockAnswerSheet(item),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavedMockAnswerSheet(Map<String, dynamic> item) async {
    final answers = (item['answers'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(item['topic']?.toString() ?? 'Saved Mock Test'),
          content: SizedBox(
            width: 520,
            child: answers.isEmpty
                ? const Text('No answer sheet data found.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: answers.length,
                    itemBuilder: (context, index) {
                      final row = answers[index];
                      final qJson = (row['question'] as Map<String, dynamic>? ??
                          const <String, dynamic>{});
                      final question = _MockQuestion.fromJson(qJson);
                      final userAnswer = row['userAnswer']?.toString() ?? '';
                      final awarded =
                          double.tryParse(row['awarded']?.toString() ?? '') ??
                              0;
                      final note = row['evaluationNote']?.toString() ?? '';
                      final imageName =
                          row['imageAnswerName']?.toString() ?? '';
                      final ratio = question.marks <= 0
                          ? 0.0
                          : (awarded / question.marks);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q${index + 1}. ${question.text}'),
                              const SizedBox(height: 6),
                              Text('Correct: ${question.correctAnswer}'),
                              const SizedBox(height: 4),
                              Text(
                                  'Your answer: ${userAnswer.isEmpty ? '(photo/text not provided)' : userAnswer}'),
                              if (imageName.trim().isNotEmpty)
                                Text('Attached photo: $imageName'),
                              if (note.trim().isNotEmpty)
                                Text('Eval note: $note'),
                              const SizedBox(height: 4),
                              Text(
                                'Score: ${awarded.toStringAsFixed(1)} / ${question.marks}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _scoreColor(ratio),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _momentumTitle(double progress) {
    if (progress >= 1) {
      return 'Journey complete. You are on fire.';
    }
    if (progress >= 0.75) {
      return 'Final stretch. Finish strong.';
    }
    if (progress >= 0.4) {
      return 'Momentum unlocked. Keep the streak alive.';
    }
    return 'Start small, win big. One task at a time.';
  }

  String _momentumSubtitle(double progress) {
    if (progress >= 1) {
      return 'Shift to resources and convert this into exam confidence.';
    }
    if (progress >= 0.75) {
      return 'You are close to mastery. Protect your focus for one more push.';
    }
    if (progress >= 0.4) {
      return 'Consistency beats intensity. Keep showing up today.';
    }
    return 'Pick the easiest next task and build instant momentum.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final template = _templates[_selectedSubject]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final setupTop = isDark
        ? Color.alphaBlend(
            template.accent.withValues(alpha: 0.24),
            Theme.of(context).colorScheme.surfaceContainerHigh,
          )
        : template.softAccent;
    final setupBottom = isDark
        ? Color.alphaBlend(
            template.accent.withValues(alpha: 0.14),
            Theme.of(context).colorScheme.surface,
          )
        : template.softAccent.withValues(alpha: 0.72);
    final setupText =
        isDark ? Theme.of(context).colorScheme.onSurface : template.accent;

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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (!_isJourneySaved || _showJourneySetup) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  setupTop,
                  setupBottom,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isDark
                    ? Theme.of(context).colorScheme.outlineVariant
                    : template.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Design Your Learning Journey',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.2),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: setupText,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set your subject and study-time target, then launch.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.84)
                              : template.accent.withValues(alpha: 0.82),
                        ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _examNameController,
                    decoration: const InputDecoration(
                      labelText: 'Exam name',
                      hintText: 'e.g. Mid-term 2026',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: _templates.values
                        .where((item) => _enabledSubjects.contains(item.key))
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Study time target: $_totalStudyMinutes minutes',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final minutes = await _showJourneyTimeDialog(
                            initialMinutes: _totalStudyMinutes,
                          );
                          if (minutes == null) {
                            return;
                          }
                          setState(() {
                            _totalStudyMinutes = minutes;
                          });
                        },
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Adjust'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _openSaveJourneyModalAndGenerate,
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: Text('Save Journey ($_totalStudyMinutes min)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetJourney,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Reset Progress'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _clearJourneyForFreshStart,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('New Journey'),
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
        ],
        _JourneyHeader(
          examName: _examNameController.text.trim(),
          template: template,
          earnedXp: earnedXp,
          totalXp: totalXp,
          progress: progress,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                template.accent.withValues(alpha: 0.92),
                template.accent.withValues(alpha: 0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _momentumTitle(progress),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _momentumSubtitle(progress),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_isJourneySaved && !_showJourneySetup)
          ..._buildStagedJourneyWidgets(allTasks),
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
        if (_isJourneySaved) const SizedBox(height: 12),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final headerTop = isDark
            ? Color.alphaBlend(
                template.accent.withValues(alpha: 0.22),
                Theme.of(context).colorScheme.surfaceContainerHigh,
              )
            : template.softAccent;
        final headerBottom = isDark
            ? Color.alphaBlend(
                template.accent.withValues(alpha: 0.12),
                Theme.of(context).colorScheme.surface,
              )
            : template.softAccent.withValues(alpha: 0.78);
        final textColor =
            isDark ? Theme.of(context).colorScheme.onSurface : template.accent;
        final title = examName.isEmpty
            ? '${template.subjectLabel} chapter checklist'
            : '$examName • ${template.subjectLabel}';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                headerTop,
                headerBottom,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.outlineVariant
                  : template.accent.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDark
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.82)
                                : template.accent.withValues(alpha: 0.82),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: template.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$earnedXp / $totalXp XP',
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.05),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Focus mode',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(progress * 100).round()}% complete',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            template.subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: isDark
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.82)
                                      : template.accent.withValues(alpha: 0.82),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: template.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$earnedXp / $totalXp XP',
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.05),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
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
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.1),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    final difficulty = task.xp >= 25
        ? 'Hard'
        : task.xp >= 15
            ? 'Medium'
            : 'Easy';
    final difficultyColor = task.xp >= 25
        ? Colors.red.shade700
        : task.xp >= 15
            ? Colors.orange.shade700
            : Colors.green.shade700;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration:
                            isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$difficulty effort task',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: difficultyColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
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
      elevation: 0,
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
                  gradient: done
                      ? LinearGradient(
                          colors: [
                            Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.42),
                            Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.22),
                          ],
                        )
                      : null,
                  color: done ? null : Theme.of(context).colorScheme.surface,
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

class _ChapterWeightage {
  const _ChapterWeightage({required this.chapter, required this.marks});

  final String chapter;
  final int marks;

  Map<String, dynamic> toJson() => {
        'chapter': chapter,
        'marks': marks,
      };

  factory _ChapterWeightage.fromJson(Map<String, dynamic> json) {
    return _ChapterWeightage(
      chapter: json['chapter']?.toString() ?? '',
      marks: int.tryParse(json['marks']?.toString() ?? '') ?? 0,
    );
  }
}

class _FlashcardItem {
  const _FlashcardItem({
    required this.front,
    required this.back,
    this.keywords = const <String>[],
  });

  final String front;
  final String back;
  final List<String> keywords;

  Map<String, dynamic> toJson() => {
        'front': front,
        'back': back,
        'keywords': keywords,
      };

  factory _FlashcardItem.fromJson(Map<String, dynamic> json) {
    return _FlashcardItem(
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
      keywords: (json['keywords'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}

class _MockQuestion {
  const _MockQuestion({
    required this.chapter,
    required this.section,
    required this.text,
    required this.type,
    required this.marks,
    required this.difficulty,
    required this.correctAnswer,
    required this.keywords,
    required this.options,
    this.tolerance,
  });

  final String chapter;
  final String section;
  final String text;
  final String type;
  final int marks;
  final String difficulty;
  final String correctAnswer;
  final List<String> keywords;
  final List<String> options;
  final double? tolerance;

  Map<String, dynamic> toJson() => {
        'chapter': chapter,
        'section': section,
        'question': text,
        'type': type,
        'marks': marks,
        'difficulty': difficulty,
        'correctAnswer': correctAnswer,
        'keywords': keywords,
        'options': options,
        'tolerance': tolerance,
      };

  _MockQuestion copyWith({
    String? chapter,
    String? section,
    String? text,
    String? type,
    int? marks,
    String? difficulty,
    String? correctAnswer,
    List<String>? keywords,
    List<String>? options,
    double? tolerance,
  }) {
    return _MockQuestion(
      chapter: chapter ?? this.chapter,
      section: section ?? this.section,
      text: text ?? this.text,
      type: type ?? this.type,
      marks: marks ?? this.marks,
      difficulty: difficulty ?? this.difficulty,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      keywords: keywords ?? this.keywords,
      options: options ?? this.options,
      tolerance: tolerance ?? this.tolerance,
    );
  }

  factory _MockQuestion.fromJson(Map<String, dynamic> json) {
    final rawAnswer = json['correctAnswer'] ??
        json['correct_answer'] ??
        json['modelAnswer'] ??
        json['model_answer'] ??
        json['expectedAnswer'] ??
        json['expected_answer'] ??
        json['sampleAnswer'] ??
        json['sample_answer'] ??
        json['solution'] ??
        json['answer'];
    String resolvedAnswer = '';
    if (rawAnswer is Map<String, dynamic>) {
      resolvedAnswer =
          (rawAnswer['text'] ?? rawAnswer['value'] ?? '').toString();
    } else {
      resolvedAnswer = rawAnswer?.toString() ?? '';
    }

    final rawKeywords = json['keywords'];
    List<String> parsedKeywords;
    if (rawKeywords is String) {
      parsedKeywords = rawKeywords
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      parsedKeywords = (rawKeywords as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    return _MockQuestion(
      chapter: json['chapter']?.toString() ?? 'General',
      section: json['section']?.toString() ?? 'Section',
      text: (json['question'] ??
              json['questionText'] ??
              json['question_text'] ??
              json['question text'] ??
              '')
          .toString(),
      type: json['type']?.toString().toLowerCase() ?? 'short',
      marks: int.tryParse(json['marks']?.toString() ?? '') ?? 1,
      difficulty: json['difficulty']?.toString() ?? 'Medium',
      correctAnswer: resolvedAnswer,
      keywords: parsedKeywords,
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      tolerance: double.tryParse(json['tolerance']?.toString() ?? ''),
    );
  }
}

class _ImageAnswerAttachment {
  const _ImageAnswerAttachment({
    required this.name,
    required this.mimeType,
    required this.base64Data,
  });

  final String name;
  final String mimeType;
  final String base64Data;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mimeType': mimeType,
        'base64Data': base64Data,
      };

  factory _ImageAnswerAttachment.fromJson(Map<String, dynamic> json) {
    return _ImageAnswerAttachment(
      name: json['name']?.toString() ?? 'answer_image.jpg',
      mimeType: json['mimeType']?.toString() ?? 'image/jpeg',
      base64Data: json['base64Data']?.toString() ?? '',
    );
  }
}

class _TheoryEvalResult {
  const _TheoryEvalResult({required this.awarded, required this.note});

  final double awarded;
  final String note;
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
