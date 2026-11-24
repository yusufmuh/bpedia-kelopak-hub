import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart'
    show MissionStage, MissionVoucher, RedeemProblem;

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/shop_engine.dart';
import '../shell.dart';
import '../widgets/widgets.dart';
import 'shop_layout.dart';
import 'shop_navigation.dart';

/// Cart: lines with quantity and undoable removal, Misi Belanja progress,
/// voucher hint, and "Checkout".
class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.cartItems;
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Keranjang')),
        body: Center(
          child: SingleChildScrollView(
            child: EmptyState(
              imageAsset: AppImages.bipyTasHati,
              title: 'Keranjangmu masih kosong',
              body: 'Yuk, pilih produk favoritmu dulu, Babes.',
              actionLabel: 'Mulai belanja',
              onAction: () => ShellScope.of(context).switchTab(ShellTab.home),
            ),
          ),
        ),
      );
    }
    final subtotal = app.cartSubtotal;
    final count = app.cartCount;
    final large = isLargeText(context);
    final subtotalRow = AmountRow(
      label: 'Subtotal ($count barang)',
      value: rupiah(subtotal),
      tone: AmountTone.total,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Keranjang ($count)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BpSpace.s4,
          BpSpace.s2,
          BpSpace.s4,
          BpSpace.s6,
        ),
        children: <Widget>[
          CenteredWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final item in items) ...<Widget>[
                  _CartLineCard(
                    key: ValueKey<String>(item.product.id),
                    item: item,
                  ),
                  const SizedBox(height: BpSpace.s3),
                ],
                if (large) ...<Widget>[
                  SoftCard(child: subtotalRow),
                  const SizedBox(height: BpSpace.s3),
                ],
                const SizedBox(height: BpSpace.s1),
                _CartHints(subtotal: subtotal),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!large) ...<Widget>[
              subtotalRow,
              const SizedBox(height: BpSpace.s3),
            ],
            FilledButton(
              onPressed: () => openCheckout(context),
              child: const Text('Checkout', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({super.key, required this.item});

  final CartItem item;

  void _remove(BuildContext context) {
    final app = AppScope.read(context);
    final removed = app.removeFromCart(item.product.id);
    if (removed == null) return;
    app.haptics.selection();
    showShopSnackBar(
      context,
      'Produk dihapus dari keranjang',
      actionLabel: 'Urungkan',
      onAction: () => app.undoRemoveFromCart(removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final product = item.product;
    return SoftCard(
      padding: const EdgeInsets.all(BpSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Lihat ${product.name}',
            excludeSemantics: true,
            onTap: () => openProduct(context, product.id),
            child: InkWell(
              onTap: () => openProduct(context, product.id),
              borderRadius: BorderRadius.circular(BpRadius.sm),
              child: ProductThumbnail(product.imageAsset),
            ),
          ),
          const SizedBox(width: BpSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: BpSpace.s1),
                PriceText(
                  product.price,
                  product.strikePrice,
                  compact: true,
                  showDiscount: false,
                ),
                const SizedBox(height: BpSpace.s2),
                Wrap(
                  spacing: BpSpace.s2,
                  runSpacing: BpSpace.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    QuantityStepper(
                      value: item.qty,
                      max: cartMaxQty,
                      onChanged: (value) {
                        final app = AppScope.read(context);
                        app.setQty(product.id, value);
                        app.haptics.selection();
                      },
                    ),
                    IconButton(
                      tooltip: 'Hapus dari keranjang',
                      color: scheme.onSurfaceVariant,
                      onPressed: () => _remove(context),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Misi Belanja progress and the best voucher hint for the current subtotal.
class _CartHints extends StatelessWidget {
  const _CartHints({required this.subtotal});

  final int subtotal;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final stage = app.activeMissionStage;
    final voucher = _voucherHint(app);
    if (stage == null && voucher == null) return const SizedBox.shrink();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (stage != null)
            _MissionProgress(
              stage: stage,
              subtotal: subtotal,
              shortfall: app.missionShortfallFor(subtotal),
            ),
          if (stage != null && voucher != null)
            const Divider(height: BpSpace.s6),
          ?voucher,
        ],
      ),
    );
  }

  /// "Voucher Rp10.000 otomatis dipakai" or "Belanja RpX lagi ...", or null
  /// without active vouchers.
  static Widget? _voucherHint(AppState app) {
    MissionVoucher? usable;
    MissionVoucher? closest;
    var closestShortfall = 0;
    for (final voucher in app.activeVouchers) {
      final problem = app.voucherProblemForCart(voucher.id);
      if (problem == null) {
        if (usable == null || voucher.amount > usable.amount) usable = voucher;
      } else if (problem == RedeemProblem.belowMinimum) {
        final shortfall = app.voucherShortfallForCart(voucher.id);
        if (closest == null || shortfall < closestShortfall) {
          closest = voucher;
          closestShortfall = shortfall;
        }
      }
    }
    if (usable != null) {
      return _HintRow(
        icon: Icons.check_circle_rounded,
        positive: true,
        title: 'Voucher ${rupiah(usable.amount)} bisa dipakai',
        body: 'Otomatis dipakai di checkout. Kamu bisa menggantinya di sana.',
      );
    }
    if (closest != null) {
      return _HintRow(
        icon: Icons.info_outline_rounded,
        positive: false,
        title: 'Voucher ${rupiah(closest.amount)} menunggu',
        body:
            'Belanja ${rupiah(closestShortfall)} lagi untuk pakai voucher '
            '${rupiah(closest.amount)}',
      );
    }
    return null;
  }
}

class _MissionProgress extends StatelessWidget {
  const _MissionProgress({
    required this.stage,
    required this.subtotal,
    required this.shortfall,
  });

  final MissionStage stage;
  final int subtotal;
  final int shortfall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = stage.minOrderSubtotal;
    final counted = subtotal < target ? subtotal : target;
    final progress = target <= 0 ? 1.0 : counted / target;
    final message = shortfall > 0
        ? 'Tambah ${rupiah(shortfall)} lagi agar pesanan ini ikut Misi Belanja '
              'tahap ${stage.number}'
        : 'Pesanan ini memenuhi syarat Misi Belanja tahap ${stage.number} '
              'setelah diterima';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const IconWell(
          size: 40,
          child: BrandIcon(BrandIcons.voucher, size: 22),
        ),
        const SizedBox(width: BpSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: BpSpace.s2),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(BpRadius.pill),
                semanticsLabel:
                    'Progres Misi Belanja tahap ${stage.number}: '
                    '${rupiah(counted)} dari ${rupiah(target)}',
              ),
              const SizedBox(height: BpSpace.s1),
              Text(
                'Hadiah: voucher ${rupiah(stage.voucherAmount)} untuk belanja '
                'berikutnya min. ${rupiah(stage.voucherMinSpend)}',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.icon,
    required this.positive,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final bool positive;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Icon(
              icon,
              color: positive
                  ? BpColors.of(context).success700
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: BpSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
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
