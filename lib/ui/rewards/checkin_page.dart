import 'dart:async';

import 'package:daily_checkin/daily_checkin.dart'
    show
        CheckInAward,
        CheckInButtonState,
        CheckInClaimButton,
        CheckInMonthProgress,
        CheckInRules,
        CheckInWeekTrack;
import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart';
import '../widgets/widgets.dart';
import 'my_rewards_page.dart';
import 'reward_copy.dart';
import 'rewards_sheets.dart';
import 'rewards_widgets.dart';

/// Check-in Harian: streak hero, the 7-tulip week ("Kebun Bipy" visual),
/// the single "Ambil 1 Kelopak" action and the 30-day progress to a free
/// product. Claiming plays petals, sound, a light vibration and a result sheet.
class CheckInPage extends StatelessWidget {
  const CheckInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final claimed = app.claimedToday;
    final live = app.liveStreak;
    const title = 'Check-in Harian';
    return BgmScope(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: pageToolbarHeight(context, title),
          title: const PageTitle(title),
          actions: demoAppBarActions(context),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: rewardsPagePadding,
            children: <Widget>[
              RewardsContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoBodyChip(),
                    _CheckInHero(
                      claimed: claimed,
                      liveStreak: live,
                      balance: app.balance,
                      claimedLine: checkInDatedAhead(app)
                          ? '${checkInReturnLine(app)}.'
                          : 'Kelopak hari ini sudah masuk. Sampai besok, Babes!',
                    ),
                    if (app.streakBroken) ...<Widget>[
                      const SizedBox(height: BpSpace.s4),
                      const StatusBanner(
                        icon: Icons.info_outline_rounded,
                        tone: StatusTone.brand,
                        title: 'Rentetanmu mulai lagi dari Hari 1.',
                        detail: Text(
                          'Kelopak yang sudah terkumpul tetap aman.',
                        ),
                      ),
                    ],
                    const SizedBox(height: BpSpace.s6),
                    _WeekCard(
                      claimed: claimed,
                      filled: app.checkInWeekFilled,
                      claimedHint: checkInReturnLine(
                        app,
                        after: '· Hari ke-${live + 1}',
                      ),
                    ),
                    const SizedBox(height: BpSpace.s4),
                    _MonthCard(day: app.checkInMonthDay, claimed: claimed),
                    const SizedBox(height: BpSpace.s4),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => showCheckInRulesSheet(context),
                        icon: const Icon(Icons.help_outline_rounded),
                        label: const Text('Cara kerja'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInHero extends StatelessWidget {
  const _CheckInHero({
    required this.claimed,
    required this.liveStreak,
    required this.balance,
    required this.claimedLine,
  });

  final bool claimed;
  final int liveStreak;
  final int balance;

  /// Lead line once claimed (when the next check-in opens).
  final String claimedLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = liveStreak > 0
        ? 'Hari ke-$liveStreak beruntun'
        : 'Mulai rentetan baru hari ini';
    final String subtitle;
    if (claimed) {
      subtitle = claimedLine;
    } else if (liveStreak > 0) {
      subtitle = 'Ambil 1 Kelopak hari ini untuk Hari ke-${liveStreak + 1}.';
    } else {
      subtitle = 'Ambil 1 Kelopak hari ini, tulip pertamamu langsung mekar.';
    }
    // Each block is its own semantics node, so screen readers meet the
    // heading first and no loose text is merged into the page item.
    final heading = Semantics(
      container: true,
      header: true,
      child: Text(
        title,
        style: theme.textTheme.displaySmall!.copyWith(
          color: BpColors.of(context).pink500,
        ),
      ),
    );
    final lead = Semantics(
      container: true,
      child: Text(
        subtitle,
        style: theme.textTheme.bodyLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final saldo = MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Saldo kamu',
            style: theme.textTheme.labelMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          KelopakAmount(balance, size: KelopakAmountSize.small),
        ],
      ),
    );
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          heading,
          const SizedBox(height: BpSpace.s1),
          lead,
          const SizedBox(height: BpSpace.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: saldo),
              const SizedBox(width: BpSpace.s2),
              const _HeroBipy(height: 96),
            ],
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: BpSpace.s1),
              lead,
              const SizedBox(height: BpSpace.s3),
              saldo,
            ],
          ),
        ),
        const SizedBox(width: BpSpace.s2),
        const _HeroBipy(height: 140),
      ],
    );
  }
}

class _HeroBipy extends StatelessWidget {
  const _HeroBipy({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.bipyMenyapa,
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => SizedBox(height: height),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.claimed,
    required this.filled,
    required this.claimedHint,
  });

  final bool claimed;
  final int filled;

  /// Line under the claimed button: when the next check-in opens.
  final String claimedHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            container: true,
            header: true,
            child: Text(
              'Rentetan ${CheckInRules.bonusEvery} hari',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: BpSpace.s1),
          Semantics(
            container: true,
            child: Text(
              'Tiap check-in, satu tulip mekar. Hari '
              'ke-${CheckInRules.bonusEvery} ada bonus '
              '+${kelopakLabel(CheckInRules.bonusKelopak)}.',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: BpSpace.s4),
          CheckInWeekTrack(
            filled: filled,
            claimedToday: claimed,
            currencyIcon: const KelopakToken(size: 16),
            bonusIcon: const GiftArt(size: 22),
          ),
          const SizedBox(height: BpSpace.s6),
          Builder(
            builder: (buttonContext) => CheckInClaimButton(
              state: claimed
                  ? CheckInButtonState.claimed
                  : CheckInButtonState.ready,
              onPressed: () => _claimToday(context, buttonContext),
              claimedHint: claimedHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.day, required this.claimed});

  final int day;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const goal = CheckInRules.productEvery;
    final reached = claimed && day >= goal;
    final remaining = goal - day;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CheckInMonthProgress(day: day, rewardImage: const GiftArt()),
          const SizedBox(height: BpSpace.s2),
          Semantics(
            container: true,
            child: Text(
              reached
                  ? 'Produk gratis hari ke-$goal sudah masuk ke Hadiahku.'
                  : 'Check-in $remaining hari lagi tanpa bolong untuk 1 produk '
                        'gratis.',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Claims today's check-in (no-op when already claimed, e.g. a double tap).
void _claimToday(BuildContext context, BuildContext buttonContext) {
  final app = AppScope.read(context);
  if (!app.canCheckIn) return;
  switch (app.claimCheckIn()) {
    case CheckInAlreadyClaimed():
      return;
    case final CheckInClaimed claim:
      _celebrate(context, buttonContext, app, claim);
  }
}

void _celebrate(
  BuildContext context,
  BuildContext buttonContext,
  AppState app,
  CheckInClaimed claim,
) {
  final award = claim.award;
  final product = award.productEntitled;
  final bonus = award.bonusKelopak > 0;
  app.feedback(
    product
        ? FeedbackEvent.productWon
        : bonus
        ? FeedbackEvent.bonus
        : FeedbackEvent.checkIn,
  );
  PetalBurst.play(
    buttonContext,
    count: product
        ? 44
        : bonus
        ? 36
        : 26,
  );
  unawaited(
    showRewardResultSheet(
      context,
      title: _resultTitle(award),
      lines: _resultLines(award, claim.newBalance),
      imageAsset: product ? AppImages.giftBox3d : AppImages.kelopakToken3d,
      primaryLabel: product ? 'Lihat Hadiahku' : 'Oke',
      onPrimary: product
          ? () {
              if (!context.mounted) return;
              openRewardsPage(
                context,
                const MyRewardsPage(initialTab: MyRewardsTab.products),
              );
            }
          : null,
      secondaryLabel: product ? 'Nanti saja' : null,
    ),
  );
}

String _resultTitle(CheckInAward award) {
  if (award.productEntitled) return 'Yay, Babes! Produk gratis untukmu';
  if (award.bonusKelopak > 0) {
    return 'Yay, Babes! Bonus ${award.streak} hari beruntun';
  }
  return 'Yay, Babes! ${signedKelopakLabel(award.dailyKelopak)} masuk';
}

List<String> _resultLines(CheckInAward award, int newBalance) {
  final special = award.productEntitled || award.bonusKelopak > 0;
  return <String>[
    if (special)
      '${signedKelopakLabel(award.dailyKelopak)} · Hari ke-${award.streak} '
          'beruntun'
    else
      'Hari ke-${award.streak} beruntun',
    if (award.bonusKelopak > 0)
      'Bonus ${award.streak} hari ${signedKelopakLabel(award.bonusKelopak)}',
    if (award.productEntitled) '1 produk gratis masuk ke Hadiahku',
    'Saldo: ${kelopakWithRupiah(newBalance)}',
  ];
}
