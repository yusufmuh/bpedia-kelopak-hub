/// App clock in WIB (UTC+7) with a Mode Demo day offset.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDayOf;
import 'package:roda_sabtu/roda_sabtu.dart' show daysUntilSaturday;

/// Hours WIB is ahead of UTC (Indonesia has no daylight saving time).
const int wibUtcOffsetHours = 7;

/// Source of "today" for every rule. [now] can be injected in tests; the demo
/// offset moves the calendar day without changing the time of day.
final class AppClock {
  AppClock({DateTime Function()? now, this.demoOffsetDays = 0})
    : now = now ?? DateTime.now;

  /// Current instant.
  final DateTime Function() now;

  /// Days added by Mode Demo (0 or more).
  int demoOffsetDays;

  /// Real WIB day without the demo offset.
  int get realToday => wibDayOf(now());

  /// WIB day used by all rules: `wibDayOf(now) + demoOffsetDays`.
  int get today => realToday + demoOffsetDays;

  /// Real time left until the next 00.00 WIB.
  Duration untilNextWibMidnight() {
    final wibMillis =
        now().toUtc().millisecondsSinceEpoch +
        wibUtcOffsetHours * Duration.millisecondsPerHour;
    final intoDay = wibMillis % Duration.millisecondsPerDay;
    return Duration(milliseconds: Duration.millisecondsPerDay - intoDay);
  }

  /// First Saturday strictly after [today] (a week ahead when today is Saturday).
  int nextSaturday() {
    final current = today;
    final days = daysUntilSaturday(current);
    return current + (days == 0 ? 7 : days);
  }
}
