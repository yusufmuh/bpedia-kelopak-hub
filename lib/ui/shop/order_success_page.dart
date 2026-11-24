import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/shop_engine.dart';
import '../orders/order_status_pill.dart';
import '../orders/order_not_found.dart';
import '../shell.dart';
import '../widgets/widgets.dart';
import 'shop_layout.dart';
import 'shop_navigation.dart';

/// "Pesanan dibuat": order number, amount paid, what happens next, and the
/// way to the order in Transaksi. Petals celebrate once when it opens.
class OrderSuccessPage extends StatefulWidget {
  const OrderSuccessPage({super.key, required this.orderId});

  /// The order that was just placed.
  final String orderId;

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  final GlobalKey _artKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final artContext = _artKey.currentContext;
      PetalBurst.play(
        artContext ?? context,
        globalOrigin: artContext == null ? null : globalCenterOf(artContext),
        count: 30,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final order = app.orderById(widget.orderId);
    if (order == null) return const OrderNotFoundPage();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final large = isLargeText(context);
    final stage = app.activeMissionStage;
    final missionStage =
        stage != null &&
            order.status == OrderStatus.shipped &&
            order.subtotal >= stage.minOrderSubtotal
        ? stage
        : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => unawaited(Navigator.of(context).maybePop()),
          ),
          const SizedBox(width: BpSpace.s1),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BpSpace.s4,
          0,
          BpSpace.s4,
          BpSpace.s6,
        ),
        children: <Widget>[
          CenteredWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Image.asset(
                  AppImages.bipyMenyapa,
                  key: _artKey,
                  height: large ? 120 : 168,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) =>
                      SizedBox(height: large ? 120 : 168),
                ),
                const SizedBox(height: BpSpace.s4),
                Semantics(
                  header: true,
                  child: Text(
                    'Pesanan dibuat',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: BpSpace.s1),
                Text(
                  'Makasih, Babes! Ini ringkasan pesananmu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: BpSpace.s6),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BpSpace.s2,
                    children: <Widget>[
                      AmountRow(label: 'No. pesanan', value: order.id),
                      AmountRow(
                        label: 'Tanggal',
                        value: wibDateLabel(order.placedDay),
                      ),
                      if (order.voucherDiscount > 0)
                        AmountRow(
                          label: 'Hemat dari voucher',
                          value: rupiah(order.voucherDiscount),
                          tone: AmountTone.saving,
                        ),
                      if (order.kelopakUsed > 0)
                        AmountRow(
                          label:
                              'Hemat dari ${kelopakLabel(order.kelopakUsed)}',
                          value: rupiah(order.kelopakDiscount),
                          tone: AmountTone.saving,
                        ),
                      AmountRow(
                        label: 'Total bayar',
                        value: rupiah(order.total),
                        tone: AmountTone.total,
                      ),
                      Semantics(
                        label: 'Status, ${order.status.label}',
                        excludeSemantics: true,
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: BpSpace.s3,
                            runSpacing: BpSpace.s1,
                            children: <Widget>[
                              Text(
                                'Status',
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              OrderStatusPill(order.status),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BpSpace.s4),
                const _NextStep(
                  icon: Icon(Icons.local_shipping_outlined),
                  text:
                      'Pesanan dalam pengiriman. Tekan Pesanan Diterima di '
                      'Transaksi setelah barang sampai.',
                ),
                if (missionStage != null) ...<Widget>[
                  const SizedBox(height: BpSpace.s3),
                  _NextStep(
                    icon: const BrandIcon(BrandIcons.voucher),
                    text:
                        'Setelah diterima, pesanan ini menyelesaikan Misi '
                        'Belanja tahap ${missionStage.number} dan voucher '
                        '${rupiah(missionStage.voucherAmount)} masuk ke '
                        'Hadiahku.',
                  ),
                ],
                if (large) ...<Widget>[
                  const SizedBox(height: BpSpace.s6),
                  const _ShopAgainButton(),
                ],
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
            FilledButton(
              onPressed: () => showOrderInTransactions(context, order.id),
              child: const Text('Lihat pesanan', textAlign: TextAlign.center),
            ),
            if (!large) ...<Widget>[
              const SizedBox(height: BpSpace.s2),
              const _ShopAgainButton(),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Belanja lagi": back to Beranda (in the bar, or in the page at large text).
class _ShopAgainButton extends StatelessWidget {
  const _ShopAgainButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => ShellScope.of(context).switchTab(ShellTab.home),
      child: const Text('Belanja lagi', textAlign: TextAlign.center),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(BpRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BpSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(color: scheme.secondary),
              child: icon,
            ),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
