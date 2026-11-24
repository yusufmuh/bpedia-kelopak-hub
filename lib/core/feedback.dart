/// Haptic feedback and the event-to-feedback table of SPEC-UIUX section 4.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'sound.dart';

/// Kind of vibration.
enum HapticKind { none, selection, light, medium, heavy, success }

/// Vibration feedback honoring the user's "Getar" switch. Never throws.
class Haptics {
  Haptics({this.enabled = true});

  /// Selection clicks are limited to 12 per second (wheel pegs).
  static const int selectionMinIntervalMs = 84;

  /// Getar switch (Akun > Suara & getar).
  bool enabled;

  final Stopwatch _stopwatch = Stopwatch()..start();
  int? _lastSelectionMs;

  /// Light click for taps, chips and wheel pegs (throttled).
  void selection() {
    if (!enabled) return;
    final now = _stopwatch.elapsedMilliseconds;
    final last = _lastSelectionMs;
    if (last != null && now - last < selectionMinIntervalMs) return;
    _lastSelectionMs = now;
    _run(HapticFeedback.selectionClick);
  }

  /// Light impact: check-in, Kelopak won, voucher issued.
  void light() => _run(HapticFeedback.lightImpact);

  /// Medium impact: streak bonus.
  void medium() => _run(HapticFeedback.mediumImpact);

  /// Heavy impact: free product won.
  void heavy() => _run(HapticFeedback.heavyImpact);

  /// Success pattern (order placed).
  void success() => _run(HapticFeedback.successNotification);

  /// Plays [kind].
  void perform(HapticKind kind) {
    switch (kind) {
      case HapticKind.none:
        return;
      case HapticKind.selection:
        selection();
      case HapticKind.light:
        light();
      case HapticKind.medium:
        medium();
      case HapticKind.heavy:
        heavy();
      case HapticKind.success:
        success();
    }
  }

  void _run(Future<void> Function() effect) {
    if (!enabled) return;
    unawaited(_perform(effect));
  }

  static Future<void> _perform(Future<void> Function() effect) async {
    try {
      await effect();
    } catch (_) {
      // Haptics are optional; devices without a vibrator stay silent.
    }
  }
}

/// UI events with their sound and vibration (SPEC-UIUX section 4).
///
/// Visuals (ripple, `PetalBurst`, result sheet) stay with the screen.
enum FeedbackEvent {
  /// Primary button on a game screen.
  tap(Sfx.tap, HapticKind.selection),

  /// Daily check-in claimed.
  checkIn(Sfx.claim, HapticKind.light),

  /// Streak bonus on day 7, 14, ...
  bonus(Sfx.bonus, HapticKind.medium),

  /// Free product won (check-in day 30 or wheel).
  productWon(Sfx.winProduct, HapticKind.heavy),

  /// Kelopak won on the wheel.
  kelopakWon(Sfx.claim, HapticKind.light),

  /// Wheel starts.
  spinStart(Sfx.spinStart, HapticKind.selection),

  /// Wheel passes a peg.
  peg(Sfx.tick, HapticKind.selection),

  /// Mission voucher issued.
  voucherIssued(Sfx.unlock, HapticKind.light),

  /// Order placed.
  orderPlaced(Sfx.notifikasi, HapticKind.success),

  /// Something is not possible (no vibration).
  softError(Sfx.softError, HapticKind.none);

  const FeedbackEvent(this.sfx, this.haptic);

  /// Sound to play.
  final Sfx sfx;

  /// Vibration to perform.
  final HapticKind haptic;
}
