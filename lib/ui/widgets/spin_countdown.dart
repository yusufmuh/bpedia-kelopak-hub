import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/app_state.dart';

/// Builds with a Roda Sabtu opening ([AppState.nextSpinOpening], or the one
/// on [saturday]) and keeps it current. While the wait is counted in whole
/// days the day change arrives through [AppState]; on the day before it
/// rebuilds whenever the minute shown changes ("22 jam 40 menit lagi").
///
/// Every screen that tells when the wheel opens goes through this, so
/// Beranda, Hadiah, Roda Sabtu and Mode Demo always show the same wait.
class SpinCountdownBuilder extends StatefulWidget {
  const SpinCountdownBuilder({super.key, required this.builder, this.saturday});

  /// Builds the content for the current opening.
  final Widget Function(BuildContext context, SpinOpening opening) builder;

  /// A specific Saturday (WIB day) instead of the next spin Saturday.
  final int? saturday;

  @override
  State<SpinCountdownBuilder> createState() => _SpinCountdownBuilderState();
}

class _SpinCountdownBuilderState extends State<SpinCountdownBuilder> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(SpinCountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saturday != widget.saturday) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SpinOpening _opening(AppState app) {
    final saturday = widget.saturday;
    return saturday == null ? app.nextSpinOpening : app.spinOpeningOn(saturday);
  }

  /// Arms a timer for the moment the minute shown changes, while the label
  /// counts clock time. In the last minute the label stays "kurang dari 1
  /// menit lagi" until [AppState] reports the new day.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final opening = _opening(AppScope.read(context));
    final left = opening.timeLeft;
    if (!opening.countsClockTime || left < const Duration(minutes: 1)) return;
    final intoMinute = left.inMicroseconds % Duration.microsecondsPerMinute;
    // Exactly on a minute (only seen with a stopped test clock) wait a whole
    // minute instead of re-arming right away.
    final untilChange = Duration(
      microseconds: intoMinute == 0
          ? Duration.microsecondsPerMinute
          : intoMinute,
    );
    _timer = Timer(untilChange + const Duration(milliseconds: 20), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _opening(AppScope.of(context)));
  }
}

/// "3 hari lagi" until the next Roda Sabtu opens, between [prefix] and
/// [suffix] (see [SpinOpening.remainingLabel]).
class SpinCountdownText extends StatelessWidget {
  const SpinCountdownText({
    super.key,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });

  /// Text before the countdown.
  final String prefix;

  /// Text after the countdown.
  final String suffix;

  /// Text style; inherits the ambient style when null.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SpinCountdownBuilder(
      builder: (context, opening) =>
          Text('$prefix${opening.remainingLabel}$suffix', style: style),
    );
  }
}
