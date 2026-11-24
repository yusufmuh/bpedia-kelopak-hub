import 'dart:math';

import 'package:kelopak_hub/core/sound.dart';
import 'package:kelopak_hub/data/key_value_store.dart';
import 'package:kelopak_hub/domain/app_state.dart';

/// WIB day number of a WIB calendar date, e.g. `wibDayFor(2026, 11, 28)` (a Saturday).
int wibDayFor(int year, int month, int day) =>
    DateTime.utc(year, month, day).difference(DateTime.utc(1970)).inDays;

/// The instant [hour]:[minute] WIB on the given WIB date.
DateTime wibInstant(
  int year,
  int month,
  int day, {
  int hour = 10,
  int minute = 0,
}) => DateTime.utc(year, month, day, hour - 7, minute);

/// Tuesday 24 Nov 2026, 10.00 WIB: the default "now" of test states.
final DateTime defaultTestNow = wibInstant(2026, 11, 24);

/// A clock whose time tests can move.
class FakeClock {
  FakeClock(this.current);

  /// Current instant.
  DateTime current;

  /// Pass this as `now`.
  DateTime now() => current;

  /// Moves the clock forward.
  void advance(Duration duration) => current = current.add(duration);
}

/// A [Random] that returns scripted values (each reduced modulo `max`).
class ScriptedRandom implements Random {
  ScriptedRandom(this.values) : assert(values.isNotEmpty);

  /// Values returned by [nextInt], cycling.
  final List<int> values;
  int _index = 0;

  @override
  int nextInt(int max) => values[_index++ % values.length] % max;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

/// Builds an [AppState] over an in-memory store with a fixed clock, silent
/// sound (or [sound]), a seeded random and, unless [watchDayChange], no
/// midnight timer.
Future<AppState> createTestAppState({
  KeyValueStore? store,
  DateTime Function()? now,
  Random? random,
  SoundService? sound,
  bool watchDayChange = false,
}) {
  return AppState.load(
    store: store ?? MemoryKeyValueStore(),
    now: now ?? () => defaultTestNow,
    sound: sound ?? SoundService.silent(),
    random: random ?? Random(7),
    watchDayChange: watchDayChange,
    watchOtherTabs: false,
  );
}

/// Silent sound that counts background-music holders like the real service.
class CountingSoundService extends SoundService {
  CountingSoundService() : super.silent();

  int _holders = 0;

  /// Screens currently asking for background music.
  int get holders => _holders;

  @override
  void startMusic() => _holders++;

  @override
  void stopMusic() {
    if (_holders > 0) _holders--;
  }
}
