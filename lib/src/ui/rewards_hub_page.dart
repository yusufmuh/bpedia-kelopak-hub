/// Zona Hadiah (`/hadiah`, SPEC-V3 §5): saldo, tiga game, hadiah menunggu,
/// voucher, riwayat, dan cara kerja.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/gifts.dart';
import '../games/game_actions.dart';
import '../host/kelopak_host.dart';
import 'game_status.dart';
import 'hub_actions.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'how_to_sheet.dart';
import 'kelopak_navigation.dart';

/// Halaman utama zona Hadiah. Membaca `KelopakScope` terdekat.
class RewardsHubPage extends StatelessWidget {
  /// Membuat halaman. [showBack] null = otomatis (ada tombol kembali bila
  /// halaman bisa ditutup).
  const RewardsHubPage({super.key, this.showBack, this.onBack});

  /// Tampilkan tombol kembali.
  final bool? showBack;

  /// Pengganti `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    final loggedIn = c.isLoggedIn;
    final pending = loggedIn ? c.pendingGifts : const <PendingGift>[];
    final gap = SliverToBoxAdapter(
      child: ColoredBox(color: tones.canvas, child: const SizedBox(height: 8)),
    );
    return GameScaffold(
      title: 'Zona Hadiah',
      showBack: showBack ?? Navigator.of(context).canPop(),
      onBack: onBack,
      actions: <Widget>[
        GameBarAction(
          icon: Icons.help_outline_rounded,
          tooltip: 'Cara pakai',
          onPressed: () => unawaited(showKelopakHowTo(context)),
        ),
      ],
      hero: _HubHero(controller: c),
      slivers: <Widget>[
        const SliverToBoxAdapter(child: _PlayTodayHeader()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList.list(
            children: <Widget>[
              for (final status in KelopakGameStatus.all(c))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KelopakGameCard(status: status),
                ),
            ],
          ),
        ),
        if (pending.isNotEmpty) ...<Widget>[
          gap,
          SliverToBoxAdapter(child: _PendingGiftsSection(gifts: pending)),
        ],
        if (loggedIn) ...<Widget>[
          gap,
          const SliverToBoxAdapter(child: _VoucherSection()),
          gap,
          const SliverToBoxAdapter(child: _LedgerSection()),
        ],
        gap,
        const SliverToBoxAdapter(child: _HowItWorks()),
      ],
    );
  }
}

class _HubHero extends StatefulWidget {
  const _HubHero({required this.controller});

  final KelopakController controller;

  @override
  State<_HubHero> createState() => _HubHeroState();
}

class _HubHeroState extends State<_HubHero> {
  final SpriteController _bipy = SpriteController();

  @override
  void dispose() {
    _bipy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    const white = Colors.white;
    final Widget info = c.isLoggedIn
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Kelopakmu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xE6FFFFFF),
                ),
              ),
              const SizedBox(height: 2),
              Semantics(
                label: 'Saldo ${kelopakLabel(c.balance)}',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Image(image: HubArt.coin, width: 38, height: 38),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: CountUpText(
                          value: c.balance,
                          bump: true,
                          style: const TextStyle(
                            fontSize: 36,
                            height: 42 / 36,
                            fontWeight: FontWeight.w800,
                            color: white,
                            shadows: <Shadow>[
                              Shadow(
                                color: Color(0x666B1439),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'senilai ${kelopakRupiah(c.balance)} · 1 Kelopak = '
                '${rupiah(c.campaign.policy.rupiahPerKelopak)}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  color: Color(0xF2FFFFFF),
                  fontFeatures: tabularFigures,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  GlassChip(
                    label: 'Riwayat',
                    leading: const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: white,
                    ),
                    onTap: () => KelopakNavigation.openPath(
                      context,
                      KelopakPaths.ledger,
                    ),
                  ),
                  GlassChip(
                    label: 'Cara pakai',
                    leading: const Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: white,
                    ),
                    onTap: () => unawaited(showKelopakHowTo(context)),
                  ),
                ],
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Hai, Babes!',
                style: TextStyle(
                  fontSize: 24,
                  height: 30 / 24,
                  fontWeight: FontWeight.w800,
                  color: white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Masuk untuk mulai kumpulkan Kelopak dan potong harga belanjamu.',
                style: TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  color: Color(0xF2FFFFFF),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: c.ensureLoggedIn,
                style: FilledButton.styleFrom(
                  backgroundColor: white,
                  foregroundColor: FestivePalette.candyBottom,
                  minimumSize: const Size(112, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Masuk'),
              ),
            ],
          );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        const PositionedDirectional(
          end: 112,
          top: -6,
          child: Bobbing(
            amplitude: 4,
            phase: 0.2,
            tilt: 0.08,
            child: Image(image: HubArt.coin, width: 26, height: 26),
          ),
        ),
        const PositionedDirectional(
          end: 4,
          top: 2,
          child: Bobbing(
            amplitude: 5,
            phase: 0.6,
            tilt: 0.12,
            child: Image(image: HubArt.coin, width: 22, height: 22),
          ),
        ),
        const PositionedDirectional(
          end: 2,
          bottom: 30,
          child: Bobbing(
            amplitude: 6,
            phase: 0.4,
            child: Image(image: HubArt.sparkle, width: 26, height: 26),
          ),
        ),
        const PositionedDirectional(
          end: 118,
          bottom: 14,
          child: Bobbing(
            amplitude: 4,
            phase: 0.8,
            tilt: -0.1,
            child: Image(image: HubArt.star, width: 22, height: 22),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: info,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Bipy, ketuk untuk menyapa',
              child: GestureDetector(
                onTap: () => _bipy.play(BipySprites.wave),
                child: SizedBox(
                  height: 150,
                  width: 96,
                  child: SpriteAnimation(
                    spec: BipySprites.idle,
                    controller: _bipy,
                    height: 150,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayTodayHeader extends StatelessWidget {
  const _PlayTodayHeader();

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Main hari ini',
                style: TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w700,
                  color: tones.text,
                ),
              ),
            ),
          ),
          Text(
            wibDateLabel(KelopakScope.of(context).today),
            style: TextStyle(fontSize: 12, color: tones.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu game di zona Hadiah: seni 3D bergerak, status hari ini, dan
/// tombol kecil.
class KelopakGameCard extends StatelessWidget {
  /// Membuat kartu dari [status].
  const KelopakGameCard({super.key, required this.status});

  /// Ringkasan game.
  final KelopakGameStatus status;

  static ImageProvider artOf(KelopakGame game) => switch (game) {
    KelopakGame.checkIn => HubArt.calendar,
    KelopakGame.wheel => HubArt.wheel,
    KelopakGame.mission => HubArt.bag,
  };

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final game = status.game;
    void open() => KelopakNavigation.openPath(context, status.path);
    final progress = status.progress;
    final filled = status.streakFilled;
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final button = CandyButton(
      label: status.actionLabel,
      expand: false,
      height: 40,
      shine: status.ready,
      pulse: status.ready,
      variant: status.ready ? CandyVariant.pink : CandyVariant.tonal,
      semanticLabel: '${status.actionLabel} ${game.title}',
      onPressed: open,
    );
    return Pressable(
      onTap: open,
      semanticLabel:
          '${game.title}. ${status.headline}. ${status.detail}. '
          '${status.actionLabel}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status.ready ? tones.brandLine : tones.line,
          ),
          boxShadow: tones.dark
              ? null
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: Row(
              children: <Widget>[
                _GameArt(game: game, ready: status.ready),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        game.title,
                        style: TextStyle(
                          fontSize: 15,
                          height: 20 / 15,
                          fontWeight: FontWeight.w700,
                          color: tones.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status.headline,
                        style: TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w600,
                          color: status.ready ? tones.brandStrong : tones.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status.detail,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          color: tones.textMuted,
                        ),
                      ),
                      if (filled != null) ...<Widget>[
                        const SizedBox(height: 6),
                        StreakDots(filled: filled),
                      ],
                      if (progress != null) ...<Widget>[
                        const SizedBox(height: 8),
                        MiniProgressBar(value: progress),
                      ],
                      if (stacked) ...<Widget>[
                        const SizedBox(height: 8),
                        button,
                      ],
                    ],
                  ),
                ),
                if (!stacked) ...<Widget>[const SizedBox(width: 8), button],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameArt extends StatelessWidget {
  const _GameArt({required this.game, required this.ready});

  final KelopakGame game;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final art = Image(
      image: KelopakGameCard.artOf(game),
      width: 60,
      height: 60,
    );
    return SizedBox.square(
      dimension: 76,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  tones.brandTint,
                  tones.brandTint.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          if (game == KelopakGame.wheel)
            SlowSpin(child: art)
          else
            Bobbing(
              amplitude: 4,
              phase: game == KelopakGame.checkIn ? 0 : 0.5,
              tilt: 0.06,
              child: art,
            ),
          if (ready)
            const PositionedDirectional(top: 6, end: 6, child: ReadyDot()),
        ],
      ),
    );
  }
}

/// Memutar [child] pelan tanpa henti (berhenti saat kurangi gerak atau tak
/// terlihat).
class SlowSpin extends StatefulWidget {
  /// Membuat putaran satu kali per [period].
  const SlowSpin({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 14),
  });

  /// Yang diputar.
  final Widget child;

  /// Lama satu putaran.
  final Duration period;

  @override
  State<SlowSpin> createState() => _SlowSpinState();
}

class _SlowSpinState extends State<SlowSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncRepeat(_turn, enabled: !reduceMotionOf(context));
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _turn,
    child: widget.child,
    builder: (context, child) =>
        Transform.rotate(angle: _turn.value * 2 * math.pi, child: child),
  );
}

/// Tujuh titik rentetan check-in.
class StreakDots extends StatelessWidget {
  /// Membuat titik dengan [filled] terisi.
  const StreakDots({super.key, required this.filled, this.onFestive = false});

  /// Titik terisi 0..7.
  final int filled;

  /// Di atas latar pesta (titik putih).
  final bool onFestive;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final on = onFestive ? Colors.white : tones.brand;
    final off = onFestive ? const Color(0x59FFFFFF) : tones.line;
    return Semantics(
      label: '$filled dari 7 hari minggu ini',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Container(
                  width: i == 6 ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < filled
                        ? (i == 6 ? FestivePalette.gold : on)
                        : off,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bar kemajuan tipis beraksen merek.
class MiniProgressBar extends StatelessWidget {
  /// Membuat bar bernilai [value] 0..1.
  const MiniProgressBar({
    super.key,
    required this.value,
    this.onFestive = false,
  });

  /// Kemajuan 0..1.
  final double value;

  /// Di atas latar pesta.
  final bool onFestive;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(
                color: onFestive ? const Color(0x33FFFFFF) : tones.muted,
              ),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: onFestive
                      ? FestivePalette.goldSheen
                      : const LinearGradient(
                          colors: <Color>[
                            FestivePalette.candyTop,
                            FestivePalette.candyBottom,
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingGiftsSection extends StatelessWidget {
  const _PendingGiftsSection({required this.gifts});

  final List<PendingGift> gifts;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    return ColoredBox(
      color: tones.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HubSectionHeader(
            title: 'Hadiah menunggu (${gifts.length})',
            art: HubArt.gift,
            actionLabel: 'Lihat semua',
            onAction: () =>
                KelopakNavigation.openPath(context, KelopakPaths.myGifts),
          ),
          if (gifts.length == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _GiftWideCard(
                gift: gifts.single,
                product: c.productOf(gifts.single.productCode),
              ),
            )
          else
            SizedBox(
              height: 150 + MediaQuery.textScalerOf(context).scale(64),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: gifts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final gift = gifts[index];
                  return _GiftRailCard(
                    gift: gift,
                    product: c.productOf(gift.productCode),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dikirim bersama pesanan berikutnya yang berisi minimal 1 produk berbayar.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: tones.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                CandyButton(
                  label: 'Belanja sekarang',
                  height: 44,
                  variant: CandyVariant.gold,
                  onPressed: c.host?.openShop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftRailCard extends StatelessWidget {
  const _GiftRailCard({required this.gift, required this.product});

  final PendingGift gift;
  final KelopakProduct? product;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final c = KelopakScope.read(context);
    final product = this.product;
    final name = product?.name ?? 'Produk gratis';
    return SizedBox(
      width: 140,
      child: Pressable(
        onTap: () {
          final code = gift.productCode;
          if (code != null) c.host?.openProduct(code);
        },
        semanticLabel: '$name, hadiah ${gift.source.label}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tones.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tones.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  GiftProductImage(product: product, size: 138),
                  const PositionedDirectional(
                    start: 6,
                    top: 6,
                    child: FestiveRibbon(label: 'Gratis'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                    color: tones.text,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                child: Text(
                  gift.source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tones.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftWideCard extends StatelessWidget {
  const _GiftWideCard({required this.gift, required this.product});

  final PendingGift gift;
  final KelopakProduct? product;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final c = KelopakScope.read(context);
    final product = this.product;
    final name = product?.name ?? 'Produk gratis';
    return Pressable(
      onTap: () {
        final code = gift.productCode;
        if (code != null) c.host?.openProduct(code);
      },
      semanticLabel: '$name, hadiah ${gift.source.label}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.goldTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  GiftProductImage(product: product, size: 84),
                  const PositionedDirectional(
                    start: 4,
                    top: 4,
                    child: FestiveRibbon(label: 'Gratis'),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w600,
                        color: tones.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Text(
                          'Rp0',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tones.brandStrong,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        if (product != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Text(
                            rupiah(product.price),
                            style: TextStyle(
                              fontSize: 12,
                              color: tones.textFaint,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: tones.textFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hadiah ${gift.source.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: tones.onGoldTint),
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

class _VoucherSection extends StatelessWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    final vouchers = c.activeVouchers;
    return ColoredBox(
      color: tones.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HubSectionHeader(
            title: vouchers.isEmpty
                ? 'Voucherku'
                : 'Voucherku (${vouchers.length})',
            art: HubArt.ticket,
            actionLabel: 'Lihat semua',
            onAction: () =>
                KelopakNavigation.openPath(context, KelopakPaths.vouchers),
          ),
          if (vouchers.isEmpty)
            HubEmptyState(
              compact: true,
              image: HubArt.ticket,
              title: 'Belum ada voucher',
              message: 'Selesaikan Misi Belanja untuk dapat voucher belanja.',
              actionLabel: 'Lihat misi',
              onAction: () =>
                  KelopakNavigation.openPath(context, KelopakPaths.mission),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: <Widget>[
                  for (final voucher in vouchers.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VoucherTicket(
                        voucher: voucher,
                        state: VoucherTicketState.usable,
                        onUse: () => useVoucherFromHub(c),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection();

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    final lines = c.ledgerHistory;
    return ColoredBox(
      color: tones.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HubSectionHeader(
            title: 'Riwayat Kelopak',
            art: HubArt.coin,
            actionLabel: lines.isEmpty ? null : 'Lihat semua',
            onAction: () =>
                KelopakNavigation.openPath(context, KelopakPaths.ledger),
          ),
          if (lines.isEmpty)
            HubEmptyState(
              compact: true,
              image: HubArt.calendar,
              title: 'Belum ada riwayat',
              message: 'Check-in hari ini untuk Kelopak pertamamu.',
              actionLabel: 'Check-in sekarang',
              onAction: () =>
                  KelopakNavigation.openPath(context, KelopakPaths.checkIn),
            )
          else ...<Widget>[
            for (var i = 0; i < lines.length && i < 3; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, indent: 68, color: tones.line),
              LedgerTile(line: lines[i]),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    const steps = <(ImageProvider, String, String)>[
      (HubArt.wheel, 'Main', 'Check-in, Roda Sabtu, Misi Belanja'),
      (HubArt.coin, 'Kumpulkan Kelopak', '1 Kelopak = Rp100'),
      (HubArt.bag, 'Potong belanja', 'Otomatis saat checkout'),
    ];
    return ColoredBox(
      color: tones.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const HubSectionHeader(title: 'Cara kerja Kelopak'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var i = 0; i < steps.length; i++) ...<Widget>[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: tones.textFaint,
                      ),
                    ),
                  Expanded(
                    child: _Step(
                      number: i + 1,
                      art: steps[i].$1,
                      title: steps[i].$2,
                      body: steps[i].$3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => unawaited(showKelopakHowTo(context)),
              style: TextButton.styleFrom(
                foregroundColor: tones.brand,
                minimumSize: const Size(48, 48),
              ),
              child: const Text(
                'Baca aturan lengkap',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.art,
    required this.title,
    required this.body,
  });

  final int number;
  final ImageProvider art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Semantics(
      label: 'Langkah $number: $title. $body',
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tones.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Image(image: art),
              ),
              PositionedDirectional(
                top: -2,
                start: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tones.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: tones.surface, width: 2),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tones.scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w700,
              color: tones.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 15 / 11,
              color: tones.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
