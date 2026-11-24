import 'dart:async';

import 'package:daily_checkin/daily_checkin.dart'
    show CheckInAward, CheckInRules;
import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart';
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
                  onPressed: () => _claimFromHome(buttonContext),
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
  const _ClaimedToday({super.key, required this.streak});

  final int streak;

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
          'Kembali besok mulai 00.00 WIB untuk Hari ke-${streak + 1}',
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

/// Claims today's check-in from the button behind [buttonContext] with the
/// full celebration: sound and vibration for the reward tier, the result
/// sheet, and petals bursting from the button.
void _claimFromHome(BuildContext buttonContext) {
  final app = AppScope.read(buttonContext);
  final shell = ShellScope.of(buttonContext);
  final origin = globalCenterOf(buttonContext);
  final outcome = app.claimCheckIn();
  switch (outcome) {
    case CheckInClaimed(:final award, :final newBalance):
      final productWon = award.productEntitled;
      final bonus = award.bonusKelopak > 0;
      app.feedback(
        productWon
            ? FeedbackEvent.productWon
            : bonus
            ? FeedbackEvent.bonus
            : FeedbackEvent.checkIn,
      );
      unawaited(
        showRewardResultSheet(
          buttonContext,
          title: _claimTitle(award),
          lines: _claimLines(award, newBalance),
          imageAsset: productWon
              ? AppImages.giftBox3d
              : AppImages.kelopakToken3d,
          primaryLabel: 'Oke',
          secondaryLabel: 'Lihat hadiah',
          onSecondary: () => shell.switchTab(ShellTab.rewards),
        ),
      );
      // Started after the sheet is pushed so the petals draw above it.
      PetalBurst.play(
        buttonContext,
        globalOrigin: origin,
        count: productWon ? 48 : (bonus ? 36 : 26),
      );
    case CheckInAlreadyClaimed():
      app.feedback(FeedbackEvent.softError);
      showShopSnackBar(
        buttonContext,
        'Kamu sudah check-in hari ini. Kembali besok mulai 00.00 WIB.',
      );
  }
}

String _claimTitle(CheckInAward award) {
  if (award.productEntitled) return 'Yay, Babes! Produk gratis untukmu';
  if (award.bonusKelopak > 0) {
    return 'Yay, Babes! Bonus ${award.streak} hari beruntun';
  }
  return 'Yay, Babes! +${kelopakLabel(award.dailyKelopak)} masuk';
}

List<String> _claimLines(CheckInAward award, int newBalance) {
  final parts = <String>[
    '+${kelopakLabel(award.dailyKelopak)}',
    if (award.bonusKelopak > 0) 'bonus ${kelopakLabel(award.bonusKelopak)}',
    if (award.productEntitled) '1 produk gratis',
  ];
  return <String>[
    if (parts.length > 1) parts.join(' + '),
    'Hari ke-${award.streak} beruntun',
    if (award.productEntitled)
      'Produk gratis tercatat di Hadiahku: ${EntitlementStatus.pending.label}',
    'Saldo sekarang ${kelopakWithRupiah(newBalance)}',
  ];
}
