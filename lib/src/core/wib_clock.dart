/// Jam aplikasi dalam WIB (UTC+7) dengan geseran hari Mode Demo.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDayOf;
import 'package:roda_sabtu/roda_sabtu.dart' show daysUntilSaturday;

import 'units.dart';

/// Sumber "hari ini" untuk semua aturan. [now] bisa disuntik saat tes; geseran
/// demo memindahkan hari kalender tanpa mengubah jam.
final class WibClock {
  /// Memakai [now] atau jam sistem.
  WibClock({DateTime Function()? now, this.demoOffsetDays = 0})
    : now = now ?? DateTime.now;

  /// Waktu nyata saat ini.
  final DateTime Function() now;

  /// Hari yang ditambahkan Mode Demo (0 atau lebih).
  int demoOffsetDays;

  /// Waktu yang dipakai aplikasi: waktu nyata digeser [demoOffsetDays] hari.
  DateTime get instant => now().add(Duration(days: demoOffsetDays));

  /// Hari WIB nyata tanpa geseran demo.
  int get realToday => wibDayOf(now());

  /// Hari WIB yang dipakai semua aturan: `wibDayOf(now) + demoOffsetDays`.
  int get today => realToday + demoOffsetDays;

  /// Waktu nyata yang tersisa sampai 00.00 WIB berikutnya.
  Duration untilNextWibMidnight() {
    final wibMillis =
        now().toUtc().millisecondsSinceEpoch +
        wibUtcOffsetHours * Duration.millisecondsPerHour;
    final intoDay = wibMillis % Duration.millisecondsPerDay;
    return Duration(milliseconds: Duration.millisecondsPerDay - intoDay);
  }

  /// Sabtu pertama setelah [today] (sepekan lagi bila hari ini Sabtu).
  int nextSaturday() {
    final current = today;
    final days = daysUntilSaturday(current);
    return current + (days == 0 ? 7 : days);
  }
}
