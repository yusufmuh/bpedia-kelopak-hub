import 'dart:async';

import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart'
    show
        OddsTable,
        PrizeKind,
        SaturdayWheel,
        SpinEligibility,
        SpinOdds,
        SpinPrize;

import '../../core/assets.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/sound.dart' show Sfx;
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart';
import '../shop/shop_layout.dart' show BottomActionBar;
import '../widgets/widgets.dart';
import 'my_rewards_page.dart';
import 'reward_copy.dart';
import 'rewards_sheets.dart';
import 'rewards_widgets.dart';

/// Roda Sabtu: status, the wheel, odds + quota + shipping, and one
/// "Putar gratis" per Saturday. The button sits in a bar at the bottom of the
/// screen, right under a one-line odds summary, so it is always in view and
/// the odds always come before it; the full table stays in the page.
///
/// The engine decides the prize before the wheel moves; the animation only
/// shows it. While spinning, the page keeps showing the pre-spin odds and
/// hides the saved result so nothing spoils the landing. After a spin, the
/// wheel and the table both show the odds it was spun with. Back navigation
/// is always allowed: the result is already saved and shown on return.
class WheelPage extends StatefulWidget {
  const WheelPage({super.key});

  @override
  State<WheelPage> createState() => _WheelPageState();
}

class _WheelPageState extends State<WheelPage> {
  static const int _pegIntervalMs = 80;

  final GlobalKey _wheelKey = GlobalKey();
  final Stopwatch _pegClock = Stopwatch()..start();
  int? _lastPegMs;
  SpinCompleted? _activeSpin;
  bool _spinning = false;
  bool _skip = false;
  int _spinToken = 0;

  void _spin() {
    final app = AppScope.read(context);
    if (_spinning || !app.canSpin) return;
    switch (app.spin()) {
      case final SpinCompleted outcome:
        setState(() {
          _activeSpin = outcome;
          _spinning = true;
          _skip = false;
          _spinToken++;
        });
        app.feedback(FeedbackEvent.spinStart);
      case SpinRejected(:final eligibility):
        app.feedback(FeedbackEvent.softError);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_rejectionText(eligibility))));
    }
  }

  void _skipAnimation() {
    if (!_spinning || _skip) return;
    setState(() => _skip = true);
  }

  void _onPegPassed() {
    final now = _pegClock.elapsedMilliseconds;
    final last = _lastPegMs;
    if (last != null && now - last < _pegIntervalMs) return;
    _lastPegMs = now;
    AppScope.read(context).feedback(FeedbackEvent.peg);
  }

  void _onSettled() {
    if (!mounted) return;
    final spin = _activeSpin;
    setState(() {
      _spinning = false;
      _skip = false;
    });
    if (spin != null) _celebrate(spin);
  }

  void _celebrate(SpinCompleted spin) {
    final app = AppScope.read(context);
    final prize = spin.prize;
    final isProduct = prize.kind == PrizeKind.product;
    if (isProduct) {
      app.feedback(FeedbackEvent.productWon);
    } else {
      app.sound.play(Sfx.claim);
      app.haptics.medium();
    }
    final wheelContext = _wheelKey.currentContext;
    if (wheelContext != null) {
      PetalBurst.play(wheelContext, count: isProduct ? 44 : 30);
    }
    unawaited(
      showRewardResultSheet(
        context,
        title: isProduct
            ? 'Yay, Babes! Kamu dapat produk gratis'
            : 'Yay, Babes! Kamu dapat ${prize.label}',
        lines: isProduct
            ? <String>[
                '1 produk gratis masuk ke Hadiahku',
                'Pengiriman: ${app.spinConfig.shippingNote}',
              ]
            : <String>[
                '${signedKelopakLabel(prize.kelopak)} sudah masuk ke saldo',
                'Saldo: ${kelopakWithRupiah(spin.newBalance)}',
              ],
        imageAsset: isProduct ? AppImages.giftBox3d : AppImages.kelopakToken3d,
        primaryLabel: isProduct ? 'Lihat Hadiahku' : 'Oke',
        onPrimary: isProduct ? _openProducts : null,
        secondaryLabel: isProduct ? 'Nanti saja' : null,
      ),
    );
  }

  void _openProducts() {
    if (!mounted) return;
    openRewardsPage(
      context,
      const MyRewardsPage(initialTab: MyRewardsTab.products),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final SpinCompleted? spin = _spinning ? _activeSpin : null;
    final record = spin?.record ?? app.todaySpin;
    final shownResult = spin == null ? app.todaySpin : null;
    final prize = shownResult == null ? null : app.prizeFor(shownResult);
    final reduceMotion = BpMotion.reduced(context);
    // The odds the shown spin was made with (saved with the spin, so they
    // survive a restart), otherwise the odds for the next spin. The wheel,
    // the table and the summary above the button always show the same list.
    final odds = record == null ? app.spinOdds : app.oddsForSpin(record);
    final stock = record == null ? app.productStock : app.stockForSpin(record);
    final Widget result = shownResult == null
        ? const SizedBox(height: BpSpace.s4)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: BpSpace.s4),
            child: _ResultCard(prize: prize, onOpenRewards: _openProducts),
          );
    // With reduced motion the wheel lands in the next frame: no skip button
    // and no "spinning" status that would flash (and be announced) for one
    // frame.
    final animating = spin != null && !reduceMotion;
    final Widget action = animating
        ? OutlinedButton.icon(
            key: const ValueKey<String>('skip'),
            onPressed: _skip ? null : _skipAnimation,
            icon: const Icon(Icons.fast_forward_rounded),
            label: const Text('Lewati animasi'),
          )
        : _SpinButton(
            key: const ValueKey<String>('spin'),
            available: app.canSpin,
            reason: _spinReason(app),
            onPressed: _spin,
          );
    const title = 'Roda Sabtu';
    return BgmScope(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: pageToolbarHeight(context, title),
          title: const PageTitle(title),
          actions: demoAppBarActions(context),
        ),
        body: SafeArea(
          top: false,
          child: FocusTraversalGroup(
            child: ListView(
              padding: rewardsPagePadding,
              children: <Widget>[
                RewardsContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const DemoBodyChip(),
                      _statusBanner(app, spinning: animating),
                      const SizedBox(height: BpSpace.s4),
                      SaturdayWheel(
                        key: _wheelKey,
                        odds: odds,
                        resultPrizeId: record?.prizeId,
                        spinToken: _spinToken,
                        landingSeed: record?.landingSeed ?? 0,
                        skipAnimation: _skip,
                        onPegPassed: _onPegPassed,
                        onSettled: _onSettled,
                        idleSemanticsValue: _idleSemanticsValue(app),
                        centerChild: ClipOval(
                          child: Image.asset(
                            AppImages.bipySenyum,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      if (reduceMotion)
                        result
                      else
                        AnimatedSize(
                          duration: BpMotion.medium,
                          curve: BpMotion.standard,
                          alignment: Alignment.topCenter,
                          child: result,
                        ),
                      if (shownResult != null) const _SpinTimeOddsCaption(),
                      OddsTable(
                        odds: odds,
                        productStock: stock,
                        shippingNote: app.spinConfig.shippingNote,
                      ),
                      const SizedBox(height: BpSpace.s3),
                      Center(
                        child: TextButton.icon(
                          onPressed: spin != null
                              ? null
                              : () => showWheelTermsSheet(context),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Syarat & ketentuan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _OddsSummary(odds: odds),
              const SizedBox(height: BpSpace.s2),
              if (reduceMotion)
                action
              else
                AnimatedSwitcher(duration: BpMotion.medium, child: action),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(AppState app, {required bool spinning}) {
    if (spinning) {
      return const StatusBanner(
        icon: Icons.autorenew_rounded,
        tone: StatusTone.brand,
        liveRegion: true,
        title: 'Roda sedang berputar',
        detail: Text('Hasil sudah ditentukan sistem. Semoga beruntung, Babes!'),
      );
    }
    final opening = app.nextSpinOpening;
    switch (app.spinEligibility) {
      case SpinEligibility.available:
        return const StatusBanner(
          icon: Icons.auto_awesome_rounded,
          tone: StatusTone.brand,
          liveRegion: true,
          title: 'Siap diputar',
          detail: Text('1x putaran gratis hari ini, sampai 23.59 WIB.'),
        );
      case SpinEligibility.alreadySpun:
        return StatusBanner(
          icon: Icons.check_circle_rounded,
          tone: StatusTone.success,
          liveRegion: true,
          title: spinUsedTitle(app),
          detail: Text(
            'Putaran berikutnya ${opening.opensAtLabel}, '
            '${opening.remainingLabel}.',
          ),
        );
      case SpinEligibility.notSaturday:
        // Not a live region: on the day before, the countdown changes every
        // minute and would be announced each time.
        return StatusBanner(
          icon: Icons.schedule_rounded,
          title: 'Buka ${opening.opensAtLabel}',
          detail: const SpinCountdownText(),
        );
      case SpinEligibility.promoInactive:
        return const StatusBanner(
          icon: Icons.pause_circle_outline_rounded,
          tone: StatusTone.warning,
          liveRegion: true,
          title: 'Promo sedang tidak aktif',
          detail: Text('Roda bisa diputar lagi saat promo aktif.'),
        );
    }
  }

  /// What the wheel tells screen readers while it shows no result.
  static String _idleSemanticsValue(AppState app) =>
      switch (app.spinEligibility) {
        SpinEligibility.available => 'Siap diputar',
        SpinEligibility.notSaturday => 'Buka ${app.nextSpinOpening.dayLabel}',
        SpinEligibility.promoInactive => 'Promo sedang tidak aktif',
        SpinEligibility.alreadySpun => spinUsedTitle(app),
      };

  /// Why "Putar gratis" is disabled and when it opens; null when it is not.
  static String? _spinReason(AppState app) {
    final opening = app.nextSpinOpening;
    final used = spinDatedAhead(app)
        ? '${spinUsedTitle(app)}.'
        : 'Putaran Sabtu ini sudah dipakai.';
    return switch (app.spinEligibility) {
      SpinEligibility.available => null,
      SpinEligibility.alreadySpun => '$used Sampai jumpa ${opening.dayLabel}.',
      SpinEligibility.notSaturday => 'Tombol aktif ${opening.opensAtLabel}.',
      SpinEligibility.promoInactive => 'Tombol aktif lagi saat promo berjalan.',
    };
  }
}

/// Says that the table under it shows the odds of this Saturday's spin
/// (they can differ from today's stock after a product was won).
class _SpinTimeOddsCaption extends StatelessWidget {
  const _SpinTimeOddsCaption();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BpSpace.s2),
      child: Semantics(
        container: true,
        child: Text(
          'Peluang saat kamu memutar Sabtu ini',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// "Peluang: Produk gratis 10% · 3 Kelopak 90%", the line right above the
/// spin button (the full table is in the page).
class _OddsSummary extends StatelessWidget {
  const _OddsSummary({required this.odds});

  final List<SpinOdds> odds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = odds
        .map((entry) => '${entry.prize.label} ${entry.percentText}')
        .join(' · ');
    return Semantics(
      container: true,
      child: Text(
        'Peluang: $summary',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _rejectionText(SpinEligibility eligibility) => switch (eligibility) {
  SpinEligibility.alreadySpun => 'Roda sudah diputar Sabtu ini.',
  SpinEligibility.notSaturday => 'Roda hanya bisa diputar hari Sabtu (WIB).',
  SpinEligibility.promoInactive => 'Promo Roda Sabtu sedang tidak aktif.',
  SpinEligibility.available => 'Roda belum bisa diputar. Coba lagi, ya.',
};

/// "Putar gratis", enabled only when a spin is available; otherwise disabled
/// with [reason] (why, and when it opens) underneath.
class _SpinButton extends StatelessWidget {
  const _SpinButton({
    super.key,
    required this.available,
    required this.reason,
    required this.onPressed,
  });

  final bool available;
  final String? reason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final why = reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FilledButton(
          onPressed: available ? onPressed : null,
          child: const Text('Putar gratis'),
        ),
        if (why != null) ...<Widget>[
          const SizedBox(height: BpSpace.s2),
          Semantics(
            container: true,
            child: Text(
              why,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Persistent "Hasil Sabtu ini" card (also after reopening the app).
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.prize, required this.onOpenRewards});

  final SpinPrize? prize;
  final VoidCallback onOpenRewards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final won = prize;
    final isProduct = won != null && won.kind == PrizeKind.product;
    final label = won?.label ?? 'Hadiah Roda Sabtu';
    final detail = isProduct
        ? 'Produk gratis tercatat di Hadiahku.'
        : 'Sudah masuk ke saldo Kelopak kamu.';
    return SoftCard(
      color: scheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: isProduct
                      ? const GiftArt(size: 44)
                      : const KelopakToken(size: 44),
                ),
                const SizedBox(width: BpSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text.rich(
                        TextSpan(
                          text: 'Hasil Sabtu ini: ',
                          children: <InlineSpan>[
                            TextSpan(
                              text: label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isProduct) ...<Widget>[
            const SizedBox(height: BpSpace.s2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onOpenRewards,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Lihat Hadiahku'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
