/// Hadiahku (`/hadiah/hadiahku`): produk gratis yang menunggu pesanan
/// berikutnya, yang sedang dikirim, dan yang sudah diterima (K17).
library;

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/gifts.dart';
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
    final onTheWay = gifts
        .where(
          (gift) =>
              gift.status == GiftStatus.attached ||
              gift.status == GiftStatus.shipped,
        )
        .toList();
    final received = gifts
        .where((gift) => gift.status == GiftStatus.received)
        .toList();
    final Widget body = gifts.isEmpty
        ? ListView(
            children: <Widget>[
              const _InfoCard(),
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
            ],
          )
        : ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              const _InfoCard(),
              if (pending.isNotEmpty)
                _GiftGroup(
                  title: 'Menunggu pesanan berikutnya',
                  gifts: pending,
                  controller: c,
                ),
              if (onTheWay.isNotEmpty)
                _GiftGroup(
                  title: 'Ikut pesananmu',
                  gifts: onTheWay,
                  controller: c,
                ),
              if (received.isNotEmpty)
                _GiftGroup(
                  title: 'Sudah diterima',
                  gifts: received,
                  controller: c,
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
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: CandyButton(
                          label: 'Keranjang',
                          variant: CandyVariant.tonal,
                          shine: false,
                          height: 48,
                          onPressed: c.host?.openCart,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CandyButton(
                          label: 'Belanja',
                          height: 48,
                          onPressed: c.host?.openShop,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return ColoredBox(
      color: tones.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tones.goldTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Bobbing(
                  amplitude: 3,
                  child: Image(image: HubArt.gift, width: 44, height: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Produk gratis ikut pesanan belanja berikutnya dan tampil '
                    'di keranjang sebagai Rp0. Syaratnya minimal 1 produk '
                    'berbayar dalam pesanan.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 17 / 12,
                      color: tones.onGoldTint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _GiftGroup extends StatelessWidget {
  const _GiftGroup({
    required this.title,
    required this.gifts,
    required this.controller,
  });

  final String title;
  final List<PendingGift> gifts;
  final KelopakController controller;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ColoredBox(
        color: tones.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HubSectionHeader(title: '$title (${gifts.length})'),
            for (var i = 0; i < gifts.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, indent: 100, color: tones.line),
              _GiftRow(gift: gifts[i], controller: controller),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.gift, required this.controller});

  final PendingGift gift;
  final KelopakController controller;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final code = gift.productCode;
    final product = controller.productOf(code);
    final name = product?.name ?? 'Produk gratis';
    final orderId = gift.orderId;
    return Semantics(
      container: true,
      label:
          '$name, hadiah ${gift.source.label}, ${gift.status.label}'
          '${orderId == null ? '' : ', pesanan $orderId'}',
      child: InkWell(
        onTap: code == null ? null : () => controller.host?.openProduct(code),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GiftProductImage(product: product),
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
                          Flexible(
                            child: Text(
                              rupiah(product.price),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: tones.textFaint,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: tones.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        GiftStatusChip(status: gift.status),
                        Text(
                          '${gift.source.label} · ${wibShortDate(gift.wonDay)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: tones.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (orderId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Pesanan $orderId',
                          style: TextStyle(
                            fontSize: 11,
                            color: tones.textMuted,
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
    );
  }
}
