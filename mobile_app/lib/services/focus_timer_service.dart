import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_store_service.dart';
import 'notification_service.dart';

class FocusTimerService {
  FocusTimerService._();

  static final FocusTimerService instance = FocusTimerService._();

  static const int _focusCompleteNotificationId = 910001;

  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);

  LocalStoreService? _storeService;
  Timer? _ticker;
  DateTime? _endAt;
  bool _initialized = false;

  bool get isRunning => _endAt != null && remaining.value > Duration.zero;

  Future<void> initialize({required LocalStoreService storeService}) async {
    _storeService = storeService;
    if (_initialized) {
      return;
    }
    _initialized = true;

    final savedEndAt = await storeService.loadFocusTimerEndsAt();
    if (savedEndAt == null) {
      return;
    }

    final diff = savedEndAt.difference(DateTime.now());
    if (diff <= Duration.zero) {
      await storeService.saveFocusTimerEndsAt(null);
      remaining.value = Duration.zero;
      _endAt = null;
      return;
    }

    _endAt = savedEndAt;
    remaining.value = diff;
    await NotificationService.instance.scheduleOneTime(
      id: _focusCompleteNotificationId,
      title: 'Focus Session Complete',
      body: 'Great work. Time for a short break.',
      at: savedEndAt,
      focusChannel: true,
    );
    _startTicker();
  }

  Future<void> start(Duration duration) async {
    await stop();

    final now = DateTime.now();
    _endAt = now.add(duration);
    remaining.value = duration;
    await _storeService?.saveFocusTimerEndsAt(_endAt);

    // Start the ticker first so countdown always works, even if notification
    // scheduling fails (e.g. exact-alarm permission denied).
    _startTicker();

    try {
      await NotificationService.instance.scheduleOneTime(
        id: _focusCompleteNotificationId,
        title: 'Focus Session Complete',
        body: 'Great work. Time for a short break.',
        at: _endAt!,
        focusChannel: true,
      );
    } catch (_) {
      // Notification failed (permission issue); timer countdown continues.
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final endAt = _endAt;
      if (endAt == null) {
        return;
      }
      final diff = endAt.difference(DateTime.now());
      if (diff <= Duration.zero) {
        NotificationService.instance.cancel(_focusCompleteNotificationId);
        NotificationService.instance.showNow(
          id: _focusCompleteNotificationId,
          title: 'Focus Session Complete ⏱',
          body: 'Great work! You stayed focused. Time for a short break.',
          focusPopup: true,
        );
        _storeService?.saveFocusTimerEndsAt(null);
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
    await NotificationService.instance.cancel(_focusCompleteNotificationId);
  }
}
