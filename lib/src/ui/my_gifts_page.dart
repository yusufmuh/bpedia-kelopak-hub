/// Hadiahku (`/hadiah/hadiahku`): spanduk hadiah menunggu, kartu hadiah
/// yang menunggu dikirim, dan riwayat kiriman bertahap (K17).
library;

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/checkout.dart';
import '../domain/gifts.dart';
import '../games/game_actions.dart';
import '../host/kelopak_host.dart';
import '../kit/kit.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'kelopak_navigation.dart';

/// Halaman hadiah produk gratis. Membaca `KelopakScope` terdekat.
class MyGiftsPage extends StatelessWidget {
  /// Membuat halaman.
  const MyGiftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    if (!c.isLoggedIn) {
      return Scaffold(
        backgroundColor: tones.surface,
        appBar: AppBar(title: const Text('Hadiahku')),
        body: Center(
          child: SingleChildScrollView(
            child: HubEmptyState(
              image: HubArt.gift,
              title: 'Masuk dulu, Babes',
              message: 'Hadiah produk gratis tersimpan di akunmu.',
              actionLabel: 'Masuk',
              onAction: c.ensureLoggedIn,
            ),
          ),
        ),
      );
    }
    final gifts = c.gifts;
    final pending = gifts.where((gift) => gift.isPending).toList();
    final sent = gifts.where((gift) => !gift.isPending).toList();
    final Widget body = gifts.isEmpty
        ? ListView(
            children: <Widget>[
              ColoredBox(
                color: tones.surface,
                child: HubEmptyState(
                  image: HubArt.bipyHost,
                  title: 'Belum ada hadiah produk',
                  message:
                      'Menangkan produk gratis di Roda Sabtu atau check-in 30 hari tanpa putus.',
                  actionLabel: 'Main Roda Sabtu',
                  onAction: () =>
                      KelopakNavigation.openPath(context, KelopakPaths.wheel),
                ),
              ),
              const _WaysToWin(),
            ],
          )
        : ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              if (pending.isNotEmpty) _WaitingBanner(count: pending.length),
              if (pending.isNotEmpty)
                _Section(
                  title: 'Menunggu dikirim',
                  subtitle: 'Ikut dikirim bersama pesanan berikutnya',
                  children: <Widget>[
                    for (final gift in pending)
                      _PendingGiftCard(gift: gift, controller: c),
                  ],
                ),
              if (sent.isNotEmpty)
                _Section(
                  title: 'Riwayat kiriman',
                  children: <Widget>[
                    for (final gift in sent)
                      _ShipmentCard(gift: gift, controller: c),
                  ],
                ),
              const _WaysToWin(),
            ],
          );
    return Scaffold(
      backgroundColor: tones.canvas,
      appBar: AppBar(title: const Text('Hadiahku')),
      body: body,
      bottomNavigationBar: pending.isEmpty
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: tones.surface,
                border: Border(top: BorderSide(color: tones.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: CandyButton(
                    label: 'Belanja sekarang',
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    height: 48,
                    onPressed: c.host?.openShop,
                  ),
                ),
              ),
            ),
    );
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return ColoredBox(
      color: tones.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Semantics(
          container: true,
          label:
              '$count hadiah menunggu. Dikirim bersama pesanan belanja '
              'berikutnya, tanpa ongkir tambahan.',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: FestivePalette.hero),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: SunburstRays(
                      opacity: 0.08,
                      center: Alignment(0.75, -0.2),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 96),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '$count hadiah menunggu',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    height: 26 / 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: _bannerShadow,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Dikirim bersama pesanan belanja '
                                  'berikutnya, tanpa ongkir tambahan.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 17 / 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    shadows: _bannerShadow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 8, top: 4),
                          child: Bobbing(
                            amplitude: 3,
                            child: Image(
                              image: HubArt.bipyCheer,
                              width: 88,
                              height: 96,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<Shadow> _bannerShadow = <Shadow>[
  Shadow(color: Color(0x736B1439), offset: Offset(0, 1), blurRadius: 3),
];

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ColoredBox(
        color: tones.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w700,
                    color: tones.text,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    color: tones.textMuted,
                  ),
                ),
              const SizedBox(height: 12),
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftPhoto extends StatelessWidget {
  const _GiftPhoto({required this.product});

  static const double size = 88;

  final KelopakProduct? product;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GiftProductImage(product: product, size: size),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(gradient: FestivePalette.candy),
                child: const Text(
                  'Gratis',
                  style: TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingGiftCard extends StatelessWidget {
  const _PendingGiftCard({required this.gift, required this.controller});

  final PendingGift gift;
  final KelopakController controller;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final code = gift.productCode;
    final product = controller.productOf(code);
    final name = product?.name ?? 'Produk gratis';
    return Semantics(
      container: true,
      label:
          '$name, hadiah ${gift.source.label}, menunggu dikirim. Ikut '
          'dikirim bersama pesanan berikutnya.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.goldTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FestivePalette.gold),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: code == null
                    ? null
                    : () => controller.host?.openProduct(code),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _GiftPhoto(product: product),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _Chip(
                            label: 'Menunggu dikirim',
                            icon: Icons.schedule_rounded,
                            background: tones.surface.withValues(alpha: 0.6),
                            foreground: tones.onGoldTint,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 19 / 14,
                              fontWeight: FontWeight.w700,
                              color: tones.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              if (product != null)
                                Text(
                                  rupiah(product.price),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tones.textFaint,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: tones.textFaint,
                                  ),
                                ),
                              Text(
                                'Rp0',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: tones.brandStrong,
                                  fontFeatures: tabularFigures,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${gift.source.label} · ${wibDateLabel(gift.wonDay)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: tones.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tones.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 18,
                        color: tones.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ikut dikirim bersama pesanan berikutnya. Tambah '
                          'minimal 1 produk berbayar.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            color: tones.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.host?.openCart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tones.brandStrong,
                        side: BorderSide(color: tones.brand, width: 1.5),
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: const StadiumBorder(),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      child: const Text(
                        'Lihat keranjang',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.host?.openShop,
                      style: FilledButton.styleFrom(
                        backgroundColor: tones.brand,
                        foregroundColor: tones.scheme.onPrimary,
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: const StadiumBorder(),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      child: const Text(
                        'Belanja sekarang',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tahap kiriman hadiah: Menunggu, Terlampir, Dikirim, Diterima.
const List<String> _steps = <String>[
  'Menunggu',
  'Terlampir',
  'Dikirim',
  'Diterima',
];

int _stepOf(GiftStatus status) => switch (status) {
  GiftStatus.pending => 0,
  GiftStatus.attached => 1,
  GiftStatus.shipped => 2,
  GiftStatus.received => 3,
};

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.gift, required this.controller});

  final PendingGift gift;
  final KelopakController controller;

  void _openOrder(String orderId) {
    final host = controller.host;
    if (host is KelopakGameActions) {
      (host as KelopakGameActions).openOrder(orderId);
    } else {
      host?.openCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final code = gift.productCode;
    final product = controller.productOf(code);
    final name = product?.name ?? 'Produk gratis';
    final orderId = gift.orderId;
    KelopakOrder? order;
    for (final candidate in controller.state.orders) {
      if (candidate.id == orderId) order = candidate;
    }
    final step = _stepOf(gift.status);
    final closed = order?.closedDay;
    final String note = switch (gift.status) {
      GiftStatus.received =>
        closed == null ? 'Sudah diterima' : 'Diterima ${wibShortDate(closed)}',
      GiftStatus.shipped => 'Sedang dikirim bersama pesananmu',
      GiftStatus.attached =>
        order == null
            ? 'Ikut pesananmu'
            : 'Terlampir sejak ${wibShortDate(order.placedDay)}, '
                  'menunggu dikirim',
      GiftStatus.pending => 'Menunggu pesanan berikutnya',
    };
    final (
      Color chipBg,
      Color chipFg,
      IconData chipIcon,
    ) = switch (gift.status) {
      GiftStatus.received => (
        tones.successTint,
        tones.success,
        Icons.check_circle_outline_rounded,
      ),
      GiftStatus.shipped => (
        tones.dark ? const Color(0xFF1B2A44) : const Color(0xFFE7F0FD),
        tones.dark ? const Color(0xFF8FB8F5) : const Color(0xFF1F5FBF),
        Icons.local_shipping_outlined,
      ),
      _ => (tones.brandTint, tones.brandStrong, Icons.link_rounded),
    };
    return Semantics(
      container: true,
      label:
          '$name, hadiah ${gift.source.label}, ${_steps[step]}'
          '${orderId == null ? '' : ', pesanan #$orderId'}. $note',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tones.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GiftProductImage(product: product, size: 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tones.text,
                          ),
                        ),
                        Text(
                          '${gift.source.label} · ${wibDateLabel(gift.wonDay)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tones.textMuted,
                          ),
                        ),
                        if (orderId != null)
                          InkWell(
                            onTap: () => _openOrder(orderId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      'Pesanan #$orderId',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tones.brandStrong,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: tones.brandStrong,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: _steps[step],
                    icon: chipIcon,
                    background: chipBg,
                    foreground: chipFg,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ExcludeSemantics(child: _Stepper(step: step)),
              const SizedBox(height: 8),
              Text(
                note,
                style: TextStyle(fontSize: 12, color: tones.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final on = tones.success;
    Widget dot(int i) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: i <= step ? on : tones.surface,
        shape: BoxShape.circle,
        border: Border.all(color: i <= step ? on : tones.line, width: 1.5),
      ),
    );
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var i = 0; i < _steps.length; i++) ...<Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: i <= step ? on : tones.line,
                            ),
                    ),
                    dot(i),
                    Expanded(
                      child: i == _steps.length - 1
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: i < step ? on : tones.line,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            for (var i = 0; i < _steps.length; i++)
              Expanded(
                child: Text(
                  _steps[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i <= step ? tones.text : tones.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WaysToWin extends StatelessWidget {
  const _WaysToWin();

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    Widget row(ImageProvider art, String title, String body, String path) =>
        InkWell(
          onTap: () => KelopakNavigation.openPath(context, path),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: <Widget>[
                  Image(image: art, width: 44, height: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tones.text,
                          ),
                        ),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            color: tones.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tones.textFaint),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ColoredBox(
        color: tones.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const HubSectionHeader(title: 'Cara dapat produk gratis'),
            row(
              HubArt.wheel,
              'Roda Sabtu',
              'Putar gratis tiap Sabtu, ada hadiah produk',
              KelopakPaths.wheel,
            ),
            Divider(height: 1, indent: 72, color: tones.line),
            row(
              HubArt.calendar,
              'Check-in 30 hari',
              'Check-in tanpa putus 30 hari, dapat 1 produk',
              KelopakPaths.checkIn,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
