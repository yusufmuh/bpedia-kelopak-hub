import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:kelopak_hub/kit.dart';

import 'main.dart';

const int _demoShippingFee = 12000;

/// Toko contoh: daftar produk demo dengan tombol tambah.
class DemoShopPage extends StatelessWidget {
  const DemoShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final host = DemoServices.of(context).host;
    final missionCodes = KelopakScope.of(context).missionProductCodes;
    return ListenableBuilder(
      listenable: host,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Toko (contoh)'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Keranjang',
              icon: Badge(
                isLabelVisible: host.cart.isNotEmpty,
                label: Text('${host.cart.values.fold(0, (a, b) => a + b)}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              onPressed: host.openCart,
            ),
          ],
        ),
        body: ListView.separated(
          itemCount: host.products.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = host.products.values.elementAt(index);
            final inCart = host.quantityOf(product.code);
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(image: product.image!, width: 52, height: 52),
              ),
              title: Text(product.name, maxLines: 2),
              subtitle: Text(
                missionCodes.contains(product.code)
                    ? '${rupiah(product.price)} · produk misi'
                    : rupiah(product.price),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => unawaited(host.addToCart(product.code)),
                child: Text(inCart == 0 ? 'Tambah' : '+1 ($inCart)'),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Keranjang contoh: barang berbayar, hadiah Rp0, sakelar Kelopak, kutipan,
/// dan tombol buat pesanan (komit ke KelopakController).
class DemoCartPage extends StatefulWidget {
  const DemoCartPage({super.key});

  @override
  State<DemoCartPage> createState() => _DemoCartPageState();
}

class _DemoCartPageState extends State<DemoCartPage> {
  bool _useKelopak = true;
  String? _voucherId;
  int _orderSeq = 0;

  @override
  Widget build(BuildContext context) {
    final services = DemoServices.of(context);
    final host = services.host;
    final c = KelopakScope.of(context);
    return ListenableBuilder(
      listenable: host,
      builder: (context, _) {
        final quote = c.quote(
          CheckoutRequest(
            lines: host.cartLines,
            shippingFee: host.cartLines.isEmpty ? 0 : _demoShippingFee,
            voucherId: _voucherId,
            useKelopak: _useKelopak,
          ),
        );
        final problem = c.problemWith(quote);
        return Scaffold(
          appBar: AppBar(title: const Text('Keranjang (contoh)')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              for (final line in host.cartLines)
                ListTile(
                  title: Text(host.products[line.productCode]!.name),
                  subtitle: Text(
                    '${line.quantity} x ${rupiah(line.unitPrice)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () =>
                        unawaited(host.setCartQuantity(line.productCode, 0)),
                  ),
                ),
              for (final gift in c.pendingGifts)
                ListTile(
                  leading: const Icon(Icons.redeem_rounded),
                  title: Text(
                    c.productOf(gift.productCode)?.name ?? 'Produk gratis',
                  ),
                  subtitle: Text('Hadiah ${gift.source.label} · Rp0'),
                ),
              if (host.cartLines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Keranjang kosong. Hadiah gratis ikut bila ada minimal 1 produk berbayar.',
                  ),
                ),
              const Divider(),
              SwitchListTile(
                title: const Text('Pakai Kelopak'),
                subtitle: Text(
                  'Saldo ${kelopakLabel(quote.kelopakBalance)}, '
                  'maksimal ${kelopakLabel(quote.kelopakMax)}',
                ),
                value: _useKelopak,
                onChanged: (value) => setState(() => _useKelopak = value),
              ),
              RadioGroup<String?>(
                groupValue: _voucherId,
                onChanged: (value) => setState(() => _voucherId = value),
                child: Column(
                  children: <Widget>[
                    for (final voucher in c.activeVouchers)
                      RadioListTile<String?>(
                        title: Text('Voucher ${rupiah(voucher.amount)}'),
                        subtitle: Text(
                          c.voucherProblemFor(voucher, quote.goodsSubtotal) ==
                                  null
                              ? 'Min. belanja ${rupiah(voucher.minSpend)}'
                              : 'Belum memenuhi min. ${rupiah(voucher.minSpend)}',
                        ),
                        value: voucher.id,
                        toggleable: true,
                      ),
                  ],
                ),
              ),
              _SummaryRow('Subtotal barang', rupiah(quote.goodsSubtotal)),
              if (quote.voucherApplied)
                _SummaryRow('Voucher', '-${rupiah(quote.voucherAmount)}'),
              if (quote.kelopakUsed > 0)
                _SummaryRow(
                  'Kelopak (${quote.kelopakUsed})',
                  '-${rupiah(quote.kelopakValue)}',
                ),
              _SummaryRow('Ongkir (demo)', rupiah(quote.shippingFee)),
              _SummaryRow('Total', rupiah(quote.total), strong: true),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CandyButton(
                  label: 'Buat pesanan',
                  sublabel: problem?.message,
                  onPressed: problem != null
                      ? null
                      : () async {
                          final id =
                              'BP-DEMO-${(++_orderSeq).toString().padLeft(4, '0')}'
                              '-${c.today}';
                          final outcome = await c.commitOrder(id, quote);
                          if (!context.mounted) return;
                          if (outcome is OrderCommitted) {
                            host.clearCart();
                            setState(() => _voucherId = null);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Pesanan $id dibuat.')),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      fontSize: strong ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Pesanan contoh: kirim, terima (misi dievaluasi), atau batalkan.
class DemoOrdersPage extends StatelessWidget {
  const DemoOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final orders = c.view.orders.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan (contoh)')),
      body: orders.isEmpty
          ? const Center(child: Text('Belum ada pesanan.'))
          : ListView(
              children: <Widget>[
                for (final order in orders)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            order.id,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Total ${rupiah(order.total)} · ${order.status.name}'
                            '${order.kelopakUsed > 0 ? ' · ${order.kelopakUsed} Kelopak' : ''}'
                            '${order.giftIds.isNotEmpty ? ' · ${order.giftIds.length} hadiah' : ''}',
                          ),
                          if (order.isOpen)
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                if (order.status == KelopakOrderStatus.placed)
                                  TextButton(
                                    onPressed: () =>
                                        unawaited(c.shipOrder(order.id)),
                                    child: const Text('Kirim'),
                                  ),
                                TextButton(
                                  onPressed: () =>
                                      unawaited(c.completeOrder(order.id)),
                                  child: const Text('Pesanan diterima'),
                                ),
                                if (order.status == KelopakOrderStatus.placed)
                                  TextButton(
                                    onPressed: () =>
                                        unawaited(c.cancelOrder(order.id)),
                                    child: const Text('Batalkan'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Panel demo: masuk/tamu, tema, kurangi gerak, geser hari, saldo, roda,
/// atur ulang, dan catatan peristiwa.
class DemoPanelPage extends StatelessWidget {
  const DemoPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = DemoServices.of(context);
    final host = services.host;
    final settings = services.settings;
    final c = KelopakScope.of(context);
    void shift(int days) {
      c.clock.demoOffsetDays += days;
      c.refreshDay();
    }

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[host, settings]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Panel demo')),
        body: ListView(
          children: <Widget>[
            SwitchListTile(
              title: const Text('Sudah masuk'),
              value: host.isLoggedIn,
              onChanged: (value) => host.isLoggedIn = value,
            ),
            SwitchListTile(
              title: const Text('Tema gelap'),
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (value) =>
                  settings.themeMode = value ? ThemeMode.dark : ThemeMode.light,
            ),
            SwitchListTile(
              title: const Text('Kurangi gerak'),
              value: settings.reduceMotion,
              onChanged: (value) => settings.reduceMotion = value,
            ),
            SwitchListTile(
              title: const Text('Promo Roda Sabtu berjalan'),
              value: c.promoActive,
              onChanged: (value) => unawaited(c.setPromoActive(value)),
            ),
            ListTile(
              title: Text('Hari WIB: ${wibDateLabel(c.today)}'),
              subtitle: Text('Geser demo: ${c.clock.demoOffsetDays} hari'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () => shift(1),
                    child: const Text('+1 hari'),
                  ),
                  OutlinedButton(
                    onPressed: () => shift(7),
                    child: const Text('+7 hari'),
                  ),
                  OutlinedButton(
                    onPressed: c.isSaturday
                        ? null
                        : () => shift(c.nextSaturday - c.today),
                    child: const Text('Ke Sabtu'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(c.grantKelopak(50)),
                    child: const Text('Isi 50 Kelopak'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(c.refillWheelQuota()),
                    child: Text('Kuota roda penuh (${c.wheelQuotaLeft})'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DemoOrdersPage(),
                      ),
                    ),
                    child: const Text('Pesanan'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      c.clock.demoOffsetDays = 0;
                      unawaited(c.resetAll());
                      host.clearCart();
                    },
                    child: const Text('Atur ulang semua'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                'Catatan suara dan peristiwa',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final line in host.log)
              ListTile(dense: true, title: Text(line)),
          ],
        ),
      ),
    );
  }
}
