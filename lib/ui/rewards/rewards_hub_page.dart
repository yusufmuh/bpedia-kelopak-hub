import 'package:daily_checkin/daily_checkin.dart'
    show CheckInRules, CheckInWeekTrack;
import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show SpinEligibility;

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../widgets/widgets.dart';
import 'check_in_claim.dart';
import 'checkin_page.dart';
import 'ledger_page.dart';
import 'missions_page.dart';
import 'my_rewards_page.dart';
import 'reward_copy.dart';
import 'rewards_sheets.dart';
import 'rewards_widgets.dart';
import 'wheel_page.dart';

/// Which card carries the single primary button of the hub.
enum _Focus { checkIn, wheel, none }

/// Tab "Hadiah": Kelopak balance, the three games with their status,
/// Hadiahku and the Kelopak rules.
///
/// Only the most useful action right now gets the filled button (check-in
/// first, then the Saturday spin); everything else is a text link. The
/// check-in button claims right here ("Ambil 1 Kelopak"), like on Beranda.
class RewardsHubPage extends StatelessWidget {
  const RewardsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final focus = app.canCheckIn
        ? _Focus.checkIn
        : app.canSpin
        ? _Focus.wheel
        : _Focus.none;
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            title: const Text('Hadiah'),
            actions: demoAppBarActions(context),
          ),
          SliverToBoxAdapter(child: _BalanceHeader(balance: app.balance)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              BpSpace.s4,
              0,
              BpSpace.s4,
              BpSpace.s8,
            ),
            sliver: SliverToBoxAdapter(
              child: RewardsContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoBodyChip(),
                    _CheckInCard(emphasized: focus == _Focus.checkIn),
                    const SizedBox(height: BpSpace.s3),
                    _WheelCard(emphasized: focus == _Focus.wheel),
                    const SizedBox(height: BpSpace.s3),
                    const _MissionCard(),
                    const SizedBox(height: BpSpace.s3),
                    const _MyRewardsCard(),
                    const SizedBox(height: BpSpace.s6),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => showKelopakRulesSheet(context),
                        icon: const Icon(Icons.help_outline_rounded),
                        label: const Text('Cara kerja Kelopak'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final large = isLargeText(context);
    final label = Text(
      'Kelopak kamu',
      style: theme.textTheme.titleSmall!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final amount = KelopakAmount(balance, size: KelopakAmountSize.large);
    final history = TextButton.icon(
      onPressed: () => openRewardsPage(context, const LedgerPage()),
      style: TextButton.styleFrom(
        padding: const EdgeInsetsDirectional.fromSTEB(
          BpSpace.s1,
          0,
          BpSpace.s3,
          0,
        ),
      ),
      icon: const Icon(Icons.history_rounded),
      label: const Text('Riwayat'),
    );
    final bipy = _HeaderBipy(height: large ? 112 : 170);
    final Widget content;
    if (large) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          label,
          const SizedBox(height: BpSpace.s1),
          amount,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: history,
                ),
              ),
              bipy,
            ],
          ),
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                label,
                const SizedBox(height: BpSpace.s1),
                amount,
                const SizedBox(height: BpSpace.s2),
                history,
              ],
            ),
          ),
          const SizedBox(width: BpSpace.s2),
          bipy,
        ],
      );
    }
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: _HeaderBackdrop()),
        RewardsContent(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 236),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BpSpace.s4,
                BpSpace.s3,
                BpSpace.s2,
                BpSpace.s6,
              ),
              child: content,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBipy extends StatelessWidget {
  const _HeaderBipy({required this.height});

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

/// Petal photo that fades into the page: strong surface veil behind the
/// text on the left, clear on the right behind Bipy, solid at the bottom.
class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final dark = theme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            AppImages.hadiahHeaderBg,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: theme.colorScheme.primaryContainer),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: <Color>[
                  surface.withValues(alpha: dark ? 0.92 : 0.8),
                  surface.withValues(alpha: dark ? 0.72 : 0.12),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const <double>[0.5, 1],
                colors: <Color>[surface.withValues(alpha: 0), surface],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card frame shared by the four hub cards.
class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.leading,
    required this.title,
    required this.action,
    this.status,
    this.detail,
    this.body,
  });

  final Widget leading;
  final String title;
  final Widget? status;
  final Widget? detail;
  final Widget? body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pill = status;
    final text = detail;
    final content = body;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(
        BpSpace.s4,
        BpSpace.s4,
        BpSpace.s4,
        BpSpace.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              RewardIconBadge(child: leading),
              const SizedBox(width: BpSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    if (pill != null) ...<Widget>[
                      const SizedBox(height: BpSpace.s1),
                      pill,
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (text != null) ...<Widget>[
            const SizedBox(height: BpSpace.s3),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              child: text,
            ),
          ],
          if (content != null) ...<Widget>[
            const SizedBox(height: BpSpace.s4),
            content,
          ],
          const SizedBox(height: BpSpace.s3),
          action,
        ],
      ),
    );
  }
}

/// Filled button when [emphasized], otherwise a quiet text link with a chevron.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return Padding(
        padding: const EdgeInsets.only(bottom: BpSpace.s1),
        child: FilledButton(
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        onPressed: onPressed,
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_right_rounded),
        label: Text(label),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.emphasized});

  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final claimed = app.claimedToday;
    final live = app.liveStreak;
    final String detail;
    if (claimed) {
      detail = 'Hari ke-$live beruntun. ${checkInReturnLine(app)}.';
    } else if (app.streakBroken) {
      detail = 'Rentetanmu mulai lagi dari Hari 1. Kelopak kamu tetap aman.';
    } else if (live > 0) {
      detail =
          'Hari ke-$live beruntun. Ambil 1 Kelopak untuk Hari ke-${live + 1}.';
    } else {
      detail =
          'Ambil 1 Kelopak tiap hari. Hari ke-${CheckInRules.bonusEvery} '
          'dapat bonus +${CheckInRules.bonusKelopak} Kelopak.';
    }
    return _HubCard(
      leading: const KelopakToken(size: 30),
      title: 'Check-in Harian',
      status: claimed
          ? const StatusPill(
              Icons.check_circle_rounded,
              'Sudah check-in hari ini',
              tone: StatusTone.success,
            )
          : const StatusPill(
              Icons.local_florist_rounded,
              'Siap diambil',
              tone: StatusTone.brand,
            ),
      detail: Text(detail),
      body: CheckInWeekTrack(
        filled: app.checkInWeekFilled,
        claimedToday: claimed,
        currencyIcon: const KelopakToken(size: 16),
        bonusIcon: const GiftArt(size: 22),
      ),
      action: claimed
          ? _CardAction(
              label: 'Lihat progres',
              emphasized: emphasized,
              onPressed: () => openRewardsPage(context, const CheckInPage()),
            )
          : const _ClaimAction(),
    );
  }
}

/// "Ambil 1 Kelopak" that claims in place (the same one-tap claim as on
/// Beranda; an open check-in always holds the hub's primary button), plus a
/// quiet link to the full Check-in Harian page.
class _ClaimAction extends StatelessWidget {
  const _ClaimAction();

  @override
  Widget build(BuildContext context) {
    final claim = Builder(
      builder: (buttonContext) => FilledButton(
        onPressed: () =>
            claimTodayWithCelebration(buttonContext, showRewardsLink: false),
        child: const Text('Ambil 1 Kelopak', textAlign: TextAlign.center),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: BpSpace.s1),
          child: claim,
        ),
        _CardAction(
          label: 'Lihat Check-in Harian',
          onPressed: () => openRewardsPage(context, const CheckInPage()),
        ),
      ],
    );
  }
}

class _WheelCard extends StatelessWidget {
  const _WheelCard({required this.emphasized});

  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final opening = app.nextSpinOpening;
    final Widget status;
    final Widget detail;
    switch (app.spinEligibility) {
      case SpinEligibility.available:
        status = const StatusPill(
          Icons.auto_awesome_rounded,
          'Siap diputar',
          tone: StatusTone.brand,
        );
        detail = const Text('1x putaran gratis hari ini, sampai 23.59 WIB.');
      case SpinEligibility.alreadySpun:
        final record = app.todaySpin;
        final label = record == null ? null : app.prizeFor(record)?.label;
        final String done;
        if (label != null) {
          done = 'Hasil: $label. ';
        } else if (spinDatedAhead(app)) {
          done = '${spinUsedTitle(app)}. ';
        } else {
          done = '';
        }
        status = const StatusPill(
          Icons.check_circle_rounded,
          'Sudah diputar',
          tone: StatusTone.success,
        );
        detail = Text(
          '${done}Buka lagi ${opening.opensAtLabel}, '
          '${opening.remainingLabel}.',
        );
      case SpinEligibility.notSaturday:
        status = StatusPill(
          Icons.schedule_rounded,
          'Buka ${opening.opensAtLabel}',
          tone: StatusTone.neutral,
        );
        detail = const SpinCountdownText(
          prefix: 'Putaran gratis berikutnya ',
          suffix: '.',
        );
      case SpinEligibility.promoInactive:
        status = const StatusPill(
          Icons.pause_circle_outline_rounded,
          'Promo tidak aktif',
          tone: StatusTone.warning,
        );
        detail = const Text('Roda bisa diputar lagi saat promo aktif.');
    }
    return _HubCard(
      leading: const MiniWheelIcon(),
      title: 'Roda Sabtu',
      status: status,
      detail: detail,
      action: _CardAction(
        label: 'Lihat roda',
        emphasized: emphasized,
        onPressed: () => openRewardsPage(context, const WheelPage()),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final stage = app.activeMissionStage;
    final waiting = app.ordersAwaitingMission.length;
    final Widget status;
    final Widget detail;
    if (stage == null) {
      status = const StatusPill(
        Icons.emoji_events_outlined,
        'Semua tahap selesai',
        tone: StatusTone.success,
      );
      detail = const Text(
        'Tahap berikutnya menunggu kampanye. Voucher kamu ada di Hadiahku.',
      );
    } else {
      status = StatusPill(
        Icons.flag_rounded,
        'Tahap ${stage.number} dari ${app.missionStages.length}',
        tone: StatusTone.brand,
      );
      detail = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Selesaikan 1 pesanan min. ${rupiah(stage.minOrderSubtotal)}, '
            'dapat voucher ${rupiah(stage.voucherAmount)} untuk belanja '
            'berikutnya.',
          ),
          if (waiting > 0) ...<Widget>[
            const SizedBox(height: BpSpace.s2),
            StatusPill(
              Icons.local_shipping_outlined,
              '$waiting pesanan menunggu diterima',
              tone: StatusTone.info,
            ),
          ],
        ],
      );
    }
    return _HubCard(
      leading: const BrandIcon(BrandIcons.bag, size: 26),
      title: 'Misi Belanja',
      status: status,
      detail: detail,
      action: _CardAction(
        label: 'Lihat misi',
        onPressed: () => openRewardsPage(context, const MissionsPage()),
      ),
    );
  }
}

class _MyRewardsCard extends StatelessWidget {
  const _MyRewardsCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return _HubCard(
      leading: const GiftArt(size: 30),
      title: 'Hadiahku',
      detail: const Text('Voucher dan produk gratis dari game kamu.'),
      body: Row(
        children: <Widget>[
          Expanded(
            child: _StatTile(
              value: app.activeVouchers.length,
              label: 'Voucher aktif',
            ),
          ),
          const SizedBox(width: BpSpace.s3),
          Expanded(
            child: _StatTile(
              value: app.entitlements.length,
              label: 'Produk gratis',
            ),
          ),
        ],
      ),
      action: _CardAction(
        label: 'Buka Hadiahku',
        onPressed: () => openRewardsPage(context, const MyRewardsPage()),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: ${groupThousands(value)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(BpRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BpSpace.s3,
            vertical: BpSpace.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                groupThousands(value),
                style: theme.textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
