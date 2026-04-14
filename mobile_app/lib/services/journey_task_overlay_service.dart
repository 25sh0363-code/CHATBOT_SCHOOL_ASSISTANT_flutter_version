import 'package:flutter/foundation.dart';

class JourneyTaskOverlayState {
  const JourneyTaskOverlayState({
    required this.visible,
    required this.running,
    required this.taskTitle,
    required this.remainingSeconds,
    required this.taskIndex,
    required this.totalTasks,
  });

  final bool visible;
  final bool running;
  final String taskTitle;
  final int remainingSeconds;
  final int taskIndex;
  final int totalTasks;

  JourneyTaskOverlayState copyWith({
    bool? visible,
    bool? running,
    String? taskTitle,
    int? remainingSeconds,
    int? taskIndex,
    int? totalTasks,
  }) {
    return JourneyTaskOverlayState(
      visible: visible ?? this.visible,
      running: running ?? this.running,
      taskTitle: taskTitle ?? this.taskTitle,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      taskIndex: taskIndex ?? this.taskIndex,
      totalTasks: totalTasks ?? this.totalTasks,
    );
  }

  static const JourneyTaskOverlayState hidden = JourneyTaskOverlayState(
    visible: false,
    running: false,
    taskTitle: '',
    remainingSeconds: 0,
    taskIndex: 0,
    totalTasks: 0,
  );
}

class JourneyTaskOverlayService {
  JourneyTaskOverlayService._();
  static final JourneyTaskOverlayService instance =
      JourneyTaskOverlayService._();

  final ValueNotifier<JourneyTaskOverlayState> state =
      ValueNotifier(JourneyTaskOverlayState.hidden);

  VoidCallback? _onNext;
  VoidCallback? _onStart;
  VoidCallback? _onPause;

  void bindActions({
    VoidCallback? onNext,
    VoidCallback? onStart,
    VoidCallback? onPause,
  }) {
    _onNext = onNext;
    _onStart = onStart;
    _onPause = onPause;
  }

  void showOrUpdate({
    required bool enabled,
    required bool running,
    required String taskTitle,
    required int remainingSeconds,
    required int taskIndex,
    required int totalTasks,
  }) {
    if (!enabled) {
      hide();
      return;
    }

    state.value = state.value.copyWith(
      visible: true,
      running: running,
      taskTitle: taskTitle,
      remainingSeconds: remainingSeconds < 0 ? 0 : remainingSeconds,
      taskIndex: taskIndex,
      totalTasks: totalTasks,
    );
  }

  void hide() {
    state.value = JourneyTaskOverlayState.hidden;
    _onNext = null;
    _onStart = null;
    _onPause = null;
  }

  void requestNextTask() {
    _onNext?.call();
  }

  void requestStart() {
    _onStart?.call();
  }

  void requestPause() {
    _onPause?.call();
  }
}
