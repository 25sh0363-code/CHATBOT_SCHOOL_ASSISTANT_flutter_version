import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_store_service.dart';

class FocusTimerService {
  FocusTimerService._();
  static final FocusTimerService instance = FocusTimerService._();

  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);

  /// Incremented each time a focus session completes.
  /// main.dart listens to this to show the completion dialog.
  final ValueNotifier<int> completionEvents = ValueNotifier(0);

  LocalStoreService? _storeService;
  Timer? _ticker;
  DateTime? _endAt;
  bool _initialized = false;

  bool get isRunning => _endAt != null && remaining.value > Duration.zero;

  Future<void> initialize({required LocalStoreService storeService}) async {
    _storeService = storeService;
    if (_initialized) return;
    _initialized = true;

    final savedEndAt = await storeService.loadFocusTimerEndsAt();
    if (savedEndAt == null) return;

    final diff = savedEndAt.difference(DateTime.now());
    if (diff <= Duration.zero) {
      await storeService.saveFocusTimerEndsAt(null);
      remaining.value = Duration.zero;
      _endAt = null;
      return;
    }

    _endAt = savedEndAt;
    remaining.value = diff;
    _startTicker();
  }

  Future<void> start(Duration duration) async {
    await stop();
    final now = DateTime.now();
    _endAt = now.add(duration);
    remaining.value = duration;
    await _storeService?.saveFocusTimerEndsAt(_endAt);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final endAt = _endAt;
      if (endAt == null) return;

      final diff = endAt.difference(DateTime.now());
      if (diff <= Duration.zero) {
        _storeService?.saveFocusTimerEndsAt(null);
        completionEvents.value++;
        remaining.value = Duration.zero;
        _ticker?.cancel();
        _ticker = null;
        _endAt = null;
        return;
      }
      remaining.value = diff;
    });
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _endAt = null;
    remaining.value = Duration.zero;
    await _storeService?.saveFocusTimerEndsAt(null);
  }
}