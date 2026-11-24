import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart' show kelopakMaxDiscountPercent;
import '../../domain/shop_engine.dart';
import '../shell.dart';
import '../widgets/widgets.dart';
import 'order_success_page.dart';
import 'shop_layout.dart';
import 'shop_navigation.dart';
import 'voucher_picker_sheet.dart';

/// Checkout (simulated payment): demo address and shipping, voucher choice,
/// optional Kelopak discount, price breakdown and "Bayar sekarang (simulasi)".
///
/// The best usable voucher is chosen automatically; Kelopak stays off until
/// the user switches it on.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? _voucherId;
  bool _useKelopak = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _voucherId = bestUsableVoucherId(AppScope.read(context));
  }

  Future<void> _pickVoucher(CheckoutQuote quote) async {
    final choice = await showVoucherPicker(
      context,
      selectedId: quote.voucherApplied ? quote.voucherId : null,
    );
    if (!mounted || choice == null) return;
    setState(() => _voucherId = choice.voucherId);
  }

  void _pay(CheckoutQuote quote) {
    if (_placing) return;
    final app = AppScope.read(context);
    final result = app.placeOrder(quote);
    switch (result) {
      case OrderPlaced(:final order):
        _placing = true;
        app.feedback(FeedbackEvent.orderPlaced);
        unawaited(
          Navigator.of(context).pushAndRemoveUntil<void>(
            pageRoute(OrderSuccessPage(orderId: order.id)),
            (route) => route.isFirst,
          ),
        );
      case OrderNotPlaced(:final problem):
        app.feedback(FeedbackEvent.softError);
        setState(() {});
        showShopSnackBar(context, switch (problem) {
          PlaceOrderProblem.emptyCart =>
            'Keranjangmu kosong. Pilih produk dulu, ya.',
          PlaceOrderProblem.quoteOutdated =>
            'Rincian harga baru saja berubah. Cek lagi sebelum bayar.',
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.isCartEmpty) return const _EmptyCheckout();
    final quote = app.quote(voucherId: _voucherId, useKelopak: _useKelopak);
    final items = app.cartItems;
    final count = app.cartCount;
    final large = isLargeText(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: const <Widget>[
          Center(child: DemoChip()),
          SizedBox(width: BpSpace.s4),
        ],
      ),
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
                const _InfoCard(
                  icon: Icon(Icons.location_on_outlined),
                  title: 'Pengguna Demo',
                  body: 'Alamat demo, Jakarta',
                  label: 'Alamat pengiriman',
                ),
                const SizedBox(height: BpSpace.s3),
                const _InfoCard(
                  icon: BrandIcon(BrandIcons.ongkir),
                  title: 'Gratis ongkir (Demo)',
                  body: 'Pengiriman reguler ke alamat demo',
                  label: 'Pengiriman',
                ),
                const SizedBox(height: BpSpace.s6),
                SectionHeader('Produk ($count)'),
                const SizedBox(height: BpSpace.s3),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BpSpace.s3,
                    children: <Widget>[
                      for (final item in items) _CheckoutLine(item: item),
                    ],
                  ),
                ),
                const SizedBox(height: BpSpace.s6),
                const SectionHeader('Hemat'),
                const SizedBox(height: BpSpace.s3),
                _VoucherRow(
                  subtitle: _voucherSubtitle(app, quote),
                  applied: quote.voucherApplied,
                  onTap: () => unawaited(_pickVoucher(quote)),
                ),
                const SizedBox(height: BpSpace.s3),
                _KelopakSwitch(
                  quote: quote,
                  balance: app.balance,
                  onChanged: (value) => setState(() => _useKelopak = value),
                ),
                const SizedBox(height: BpSpace.s6),
                const SectionHeader('Rincian harga'),
                const SizedBox(height: BpSpace.s3),
                SoftCard(
                  child: _PriceBreakdown(quote: quote, count: count),
                ),
                const SizedBox(height: BpSpace.s3),
                const _SimulationNote(),
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
              AmountRow(
                label: 'Total bayar',
                value: rupiah(quote.total),
                tone: AmountTone.total,
              ),
              const SizedBox(height: BpSpace.s3),
            ],
            FilledButton(
              onPressed: _placing ? null : () => _pay(quote),
              child: const Text(
                'Bayar sekarang (simulasi)',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _voucherSubtitle(AppState app, CheckoutQuote quote) {
    if (quote.voucherApplied) {
      return 'Voucher ${rupiah(quote.voucherDiscount)} dipakai';
    }
    final selectedId = quote.voucherId;
    final problem = quote.voucherProblem;
    if (selectedId != null && problem != null) {
      return voucherProblemText(
        problem,
        shortfall: app.voucherShortfallForCart(selectedId),
      );
    }
    final active = app.activeVouchers;
    if (active.isEmpty) return 'Belum ada voucher. Dapatkan dari Misi Belanja.';
    final usable = active
        .where((voucher) => app.voucherProblemForCart(voucher.id) == null)
        .length;
    if (usable > 0) return '$usable voucher bisa dipakai';
    return '${active.length} voucher belum bisa dipakai';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.label,
  });

  final Widget icon;
  final String title;
  final String body;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: '$label: $title, $body',
      excludeSemantics: true,
      child: SoftCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(color: scheme.secondary),
              child: icon,
            ),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(title, style: theme.textTheme.titleSmall),
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
      ),
    );
  }
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = item.product;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ProductThumbnail(product.imageAsset, size: 56),
        const SizedBox(width: BpSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.qty} × ${rupiah(product.price)}',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({
    required this.subtitle,
    required this.applied,
    required this.onTap,
  });

  final String subtitle;
  final bool applied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Voucher, $subtitle',
      hint: 'Pilih voucher',
      excludeSemantics: true,
      onTap: onTap,
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const IconWell(
              size: 40,
              child: BrandIcon(BrandIcons.voucher, size: 22),
            ),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Voucher', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: applied
                          ? BpColors.of(context).success700
                          : scheme.onSurfaceVariant,
                      fontWeight: applied ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BpSpace.s2),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _KelopakSwitch extends StatelessWidget {
  const _KelopakSwitch({
    required this.quote,
    required this.balance,
    required this.onChanged,
  });

  final CheckoutQuote quote;
  final int balance;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = quote.maxKelopak;
    final String subtitle;
    if (balance <= 0) {
      subtitle = 'Belum ada Kelopak. Kumpulkan dari Check-in Harian.';
    } else if (max <= 0) {
      subtitle = 'Total belanja terlalu kecil untuk dipotong Kelopak.';
    } else {
      subtitle =
          'Maks. $kelopakMaxDiscountPercent% dari total belanja (Demo) · '
          'saldo ${kelopakLabel(balance)}';
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = max > 0;
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: BpSpace.s1),
      child: SwitchListTile(
        value: quote.useKelopak && enabled,
        onChanged: enabled ? onChanged : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: BpSpace.s4),
        secondary: const IconWell(size: 40, child: KelopakToken(size: 26)),
        title: Text(
          enabled
              ? 'Pakai ${kelopakLabel(max)} · hemat ${kelopakRupiah(max)}'
              : 'Pakai Kelopak',
          style: theme.textTheme.bodyLarge!.copyWith(
            color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.quote, required this.count});

  final CheckoutQuote quote;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BpSpace.s2,
      children: <Widget>[
        AmountRow(
          label: 'Subtotal ($count barang)',
          value: rupiah(quote.subtotal),
        ),
        if (quote.voucherApplied)
          AmountRow(
            label: 'Voucher Misi Belanja',
            value: rupiah(-quote.voucherDiscount),
            semanticValue: 'potongan ${rupiah(quote.voucherDiscount)}',
            tone: AmountTone.saving,
          ),
        if (quote.kelopakUsed > 0)
          AmountRow(
            label: 'Pakai ${kelopakLabel(quote.kelopakUsed)}',
            value: rupiah(-quote.kelopakDiscount),
            semanticValue: 'potongan ${rupiah(quote.kelopakDiscount)}',
            tone: AmountTone.saving,
          ),
        const AmountRow(label: 'Ongkir', value: 'Gratis'),
        const Divider(height: BpSpace.s3),
        AmountRow(
          label: 'Total bayar',
          value: rupiah(quote.total),
          tone: AmountTone.total,
        ),
      ],
    );
  }
}

class _SimulationNote extends StatelessWidget {
  const _SimulationNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IconText(
      Icons.info_outline_rounded,
      'Pembayaran ini simulasi. Tidak ada uang yang ditarik dan semua data '
      'tersimpan di perangkat ini.',
      iconSize: 18,
      style: theme.textTheme.labelMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: SingleChildScrollView(
          child: EmptyState(
            imageAsset: AppImages.bipyTasHati,
            title: 'Keranjangmu kosong',
            body: 'Tambahkan produk dulu, lalu kembali ke checkout.',
            actionLabel: 'Mulai belanja',
            onAction: () => ShellScope.of(context).switchTab(ShellTab.home),
          ),
        ),
      ),
    );
  }
}
