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
import '../widgets/widgets.dart';
import 'my_rewards_page.dart';
import 'rewards_sheets.dart';
import 'rewards_widgets.dart';

/// Roda Sabtu: status, the wheel, odds + quota + shipping (always above the
/// button) and one "Putar gratis" per Saturday.
///
/// The engine decides the prize before the wheel moves; the animation only
/// shows it. While spinning, the page keeps showing the pre-spin odds and
/// hides the saved result so nothing spoils the landing. Back navigation is
/// always allowed: the result is already saved and shown on return.
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
  int _stockBeforeSpin = 0;
  bool _spinning = false;
  bool _skip = false;
  int _spinToken = 0;

  void _spin() {
    final app = AppScope.read(context);
    if (_spinning || !app.canSpin) return;
    final stockBefore = app.productStock;
    switch (app.spin()) {
      case final SpinCompleted outcome:
        setState(() {
          _activeSpin = outcome;
          _stockBeforeSpin = stockBefore;
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
        imageAsset: isProduct ? AppImages.giftBox3d : AppImages.bipyWink,
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

  /// Wheel segments: the odds the shown spin was made with (saved with the
  /// spin, so they survive a restart), otherwise the odds for the next spin.
  List<SpinOdds> _wheelOdds(AppState app, SpinRecord? record) =>
      record == null ? app.spinOdds : app.oddsForSpin(record);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final SpinCompleted? spin = _spinning ? _activeSpin : null;
    final record = spin?.record ?? app.todaySpin;
    final shownResult = spin == null ? app.todaySpin : null;
    final prize = shownResult == null ? null : app.prizeFor(shownResult);
    final reduceMotion = BpMotion.reduced(context);
    final Widget result = shownResult == null
        ? const SizedBox(height: BpSpace.s4)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: BpSpace.s4),
            child: _ResultCard(prize: prize, onOpenRewards: _openProducts),
          );
    final Widget action = spin != null
        ? OutlinedButton.icon(
            key: const ValueKey<String>('skip'),
            onPressed: _skip ? null : _skipAnimation,
            icon: const Icon(Icons.fast_forward_rounded),
            label: const Text('Lewati animasi'),
          )
        : _SpinButton(
            key: const ValueKey<String>('spin'),
            eligibility: app.spinEligibility,
            nextSaturday: app.nextSaturday,
            onPressed: _spin,
          );
    return BgmScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Roda Sabtu'),
          actions: demoAppBarActions,
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
                    _statusBanner(app, spinning: spin != null),
                    const SizedBox(height: BpSpace.s4),
                    SaturdayWheel(
                      key: _wheelKey,
                      odds: _wheelOdds(app, record),
                      resultPrizeId: record?.prizeId,
                      spinToken: _spinToken,
                      landingSeed: record?.landingSeed ?? 0,
                      skipAnimation: _skip,
                      onPegPassed: _onPegPassed,
                      onSettled: _onSettled,
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
                    OddsTable(
                      odds: spin?.odds ?? app.spinOdds,
                      productStock: spin == null
                          ? app.productStock
                          : _stockBeforeSpin,
                      shippingNote: app.spinConfig.shippingNote,
                    ),
                    const SizedBox(height: BpSpace.s6),
                    if (reduceMotion)
                      action
                    else
                      AnimatedSwitcher(
                        duration: BpMotion.medium,
                        child: action,
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
    final nextSaturday = shortDateLabel(app.nextSaturday);
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
          title: 'Sudah diputar Sabtu ini',
          detail: Text('Putaran berikutnya Sabtu, $nextSaturday · 00.00 WIB.'),
        );
      case SpinEligibility.notSaturday:
        return StatusBanner(
          icon: Icons.schedule_rounded,
          liveRegion: true,
          title: 'Buka Sabtu, $nextSaturday · 00.00 WIB',
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
}

String _rejectionText(SpinEligibility eligibility) => switch (eligibility) {
  SpinEligibility.alreadySpun => 'Roda sudah diputar Sabtu ini.',
  SpinEligibility.notSaturday => 'Roda hanya bisa diputar hari Sabtu (WIB).',
  SpinEligibility.promoInactive => 'Promo Roda Sabtu sedang tidak aktif.',
  SpinEligibility.available => 'Roda belum bisa diputar. Coba lagi, ya.',
};

/// "Putar gratis", enabled only when a spin is available; otherwise disabled
/// with the reason and the next step underneath.
class _SpinButton extends StatelessWidget {
  const _SpinButton({
    super.key,
    required this.eligibility,
    required this.nextSaturday,
    required this.onPressed,
  });

  final SpinEligibility eligibility;
  final int nextSaturday;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = eligibility == SpinEligibility.available;
    final date = shortDateLabel(nextSaturday);
    final String? reason = switch (eligibility) {
      SpinEligibility.available => null,
      SpinEligibility.alreadySpun =>
        'Putaran Sabtu ini sudah dipakai. Sampai jumpa Sabtu, $date.',
      SpinEligibility.notSaturday =>
        'Tombol aktif Sabtu, $date mulai 00.00 WIB.',
      SpinEligibility.promoInactive => 'Tombol aktif lagi saat promo berjalan.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FilledButton(
          onPressed: available ? onPressed : null,
          child: const Text('Putar gratis'),
        ),
        if (reason != null) ...<Widget>[
          const SizedBox(height: BpSpace.s2),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
