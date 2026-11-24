/// When the next Roda Sabtu opens, worded the same way on every screen.
library;

import '../core/format.dart' as format;

/// The opening of Roda Sabtu at 00.00 WIB of [day], seen from today.
///
/// Beranda, Hadiah, Roda Sabtu and Mode Demo all describe the wait with
/// [opensAtLabel] and [remainingLabel], so the screens always agree: whole
/// calendar days until the day before ("3 hari lagi"), then the real time
/// left ("22 jam 40 menit lagi").
final class SpinOpening {
  const SpinOpening({
    required this.day,
    required this.daysLeft,
    required this.timeLeft,
  });

  /// WIB day (a Saturday) on which the wheel opens.
  final int day;

  /// Calendar days from today to [day] (1 on the day before).
  final int daysLeft;

  /// Real time left until 00.00 WIB of [day].
  final Duration timeLeft;

  /// "Sabtu, 28 Nov".
  String get dayLabel =>
      '${format.weekdayName(day)}, ${format.shortDateLabel(day)}';

  /// "Sabtu, 28 Nov · 00.00 WIB".
  String get opensAtLabel => '$dayLabel · 00.00 WIB';

  /// "3 hari lagi" while [daysLeft] is more than 1, then the real time left:
  /// "22 jam 40 menit lagi", "30 menit lagi", "kurang dari 1 menit lagi".
  String get remainingLabel => daysLeft > 1
      ? '$daysLeft hari lagi'
      : '${format.countdownLabel(timeLeft)} lagi';

  /// Whether [remainingLabel] counts hours and minutes, so it changes every
  /// minute instead of once a day.
  bool get countsClockTime => daysLeft <= 1;

  @override
  bool operator ==(Object other) =>
      other is SpinOpening &&
      other.day == day &&
      other.daysLeft == daysLeft &&
      other.timeLeft == timeLeft;

  @override
  int get hashCode => Object.hash(day, daysLeft, timeLeft);
}
