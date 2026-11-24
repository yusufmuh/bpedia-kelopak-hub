import 'package:daily_checkin/daily_checkin.dart' show CheckInRules;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../rewards/check_in_claim.dart';
import '../rewards/reward_copy.dart';
import '../shell.dart';
import '../shop/shop_layout.dart';
import '../shop/shop_navigation.dart';
import '../widgets/widgets.dart';
import 'game_tiles.dart';

/// "Kelopak hari ini" on Beranda: the balance plus today's check-in, as one
/// card that changes with the state (ready to claim, or claimed with the
/// streak), and a line when Roda Sabtu can be spun.
class KelopakTodayCard extends StatelessWidget {
  const KelopakTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final claimed = app.claimedToday;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('Kelopak hari ini', style: text.titleMedium),
          ),
          const SizedBox(height: BpSpace.s2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: KelopakAmount(app.balance),
          ),
          const SizedBox(height: BpSpace.s3),
          AnimatedSwitcher(
            duration: BpMotion.resolve(context, BpMotion.medium),
            switchInCurve: BpMotion.standard,
            switchOutCurve: BpMotion.standard,
            transitionBuilder: _fadeAndSize,
            child: claimed
                ? _ClaimedToday(
                    key: const ValueKey<String>('claimed'),
                    streak: app.liveStreak,
                    returnLine: checkInReturnLine(
                      app,
                      after: 'untuk Hari ke-${app.liveStreak + 1}',
                    ),
                  )
                : _ReadyToClaim(
                    key: const ValueKey<String>('ready'),
                    nextDay: app.nextCheckInStreakDay,
                    streakBroken: app.streakBroken,
                  ),
          ),
          if (app.canSpin) ...<Widget>[
            const Divider(height: BpSpace.s6),
            const _SpinReadyRow(),
          ],
        ],
      ),
    );
  }

  static Widget _fadeAndSize(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: child,
      ),
    );
  }
}

/// The claim button fills phone cards but stops growing on wide screens.
const double _maxButtonWidth = 420;

class _ReadyToClaim extends StatelessWidget {
  const _ReadyToClaim({
    super.key,
    required this.nextDay,
    required this.streakBroken,
  });

  final int nextDay;
  final bool streakBroken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rewards = <String>[
      '+${kelopakLabel(CheckInRules.dailyKelopak)}',
      if (nextDay % CheckInRules.bonusEvery == 0)
        'bonus ${kelopakLabel(CheckInRules.bonusKelopak)}',
      if (nextDay % CheckInRules.productEvery == 0) '1 produk gratis',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Hari ke-$nextDay: ${rewards.join(' + ')}',
          style: theme.textTheme.titleSmall,
        ),
        if (streakBroken) ...<Widget>[
          const SizedBox(height: BpSpace.s1),
          Text(
            'Rentetanmu mulai lagi dari Hari 1. Kelopak yang sudah kamu '
            'kumpulkan tetap aman.',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: BpSpace.s3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxButtonWidth),
            child: SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (buttonContext) => FilledButton(
                  onPressed: () => claimTodayWithCelebration(buttonContext),
                  child: const Text(
                    'Ambil 1 Kelopak',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClaimedToday extends StatelessWidget {
  const _ClaimedToday({
    super.key,
    required this.streak,
    required this.returnLine,
  });

  final int streak;

  /// When the next check-in opens ("Kembali besok mulai 00.00 WIB …").
  final String returnLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        IconText(
          Icons.check_circle_rounded,
          'Sudah check-in · Hari ke-$streak beruntun',
          iconSize: 20,
          iconColor: BpColors.of(context).success700,
          style: theme.textTheme.titleSmall!,
        ),
        const SizedBox(height: BpSpace.s1),
        Text(
          returnLine,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: BpSpace.s1),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => ShellScope.of(context).switchTab(ShellTab.rewards),
            style: TextButton.styleFrom(
              padding: const EdgeInsetsDirectional.only(end: BpSpace.s2),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Lihat hadiah'),
          ),
        ),
      ],
    );
  }
}

class _SpinReadyRow extends StatelessWidget {
  const _SpinReadyRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const MiniWheelIcon(size: 28),
        const SizedBox(width: BpSpace.s3),
        Expanded(
          child: Text(
            'Roda Sabtu siap diputar',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: BpSpace.s2),
        TextButton(
          onPressed: () => openWheel(context),
          child: const Text('Putar'),
        ),
      ],
    );
  }
}
