import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/shop_engine.dart';
import '../shell.dart';
import '../shop/shop_layout.dart';
import '../shop/shop_navigation.dart';
import '../widgets/widgets.dart';
import 'order_status_pill.dart';

/// Transaksi tab: orders newest first, filtered by Semua / Dikirim / Selesai.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.orders;
    final shown = app.ordersWithStatus(_filter);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: all.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  imageAsset: AppImages.bipyNgintip,
                  title: 'Belum ada transaksi',
                  body: 'Pesanan yang kamu buat akan muncul di sini.',
                  actionLabel: 'Mulai belanja',
                  onAction: () =>
                      ShellScope.of(context).switchTab(ShellTab.home),
                ),
              ),
            )
          : CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: CenteredWidth(
                    child: _StatusFilter(
                      selected: _filter,
                      counts: <OrderStatus?, int>{
                        null: all.length,
                        for (final status in OrderStatus.values)
                          status: app.ordersWithStatus(status).length,
                      },
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(BpSpace.s6),
                        child: Text(
                          _filter == OrderStatus.shipped
                              ? 'Tidak ada pesanan yang sedang dikirim.'
                              : 'Belum ada pesanan yang selesai.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      BpSpace.s4,
                      BpSpace.s2,
                      BpSpace.s4,
                      BpSpace.s8,
                    ),
                    sliver: SliverList.separated(
                      itemCount: shown.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: BpSpace.s3),
                      itemBuilder: (context, index) => CenteredWidth(
                        child: _OrderCard(
                          key: ValueKey<String>(shown[index].id),
                          order: shown[index],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final OrderStatus? selected;
  final Map<OrderStatus?, int> counts;
  final ValueChanged<OrderStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(OrderStatus?, String)>[
      (null, 'Semua'),
      for (final status in OrderStatus.values) (status, status.label),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        BpSpace.s4,
        BpSpace.s2,
        BpSpace.s4,
        BpSpace.s2,
      ),
      child: Row(
        spacing: BpSpace.s2,
        children: <Widget>[
          for (final (status, label) in options)
            FilterChip(
              label: Text('$label (${counts[status] ?? 0})'),
              selected: selected == status,
              onSelected: (_) => onChanged(status),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final first = order.lines.isEmpty ? null : order.lines.first;
    final others = order.lines.length - 1;
    final shipped = order.status == OrderStatus.shipped;
    final summary = StringBuffer('Pesanan ${order.id}, ${order.status.label}, ')
      ..write('${wibDateLabel(order.placedDay)}, ')
      ..write('${order.itemCount} barang, total ${rupiah(order.total)}');
    if (shipped) summary.write('. Konfirmasi setelah barang sampai');

    return Semantics(
      container: true,
      button: true,
      label: summary.toString(),
      child: SoftCard(
        onTap: () => openOrder(context, order.id),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: BpSpace.s2,
                runSpacing: BpSpace.s2,
                children: <Widget>[
                  Text(order.id, style: text.titleSmall),
                  OrderStatusPill(order.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                wibDateLabel(order.placedDay),
                style: text.labelMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (first != null) ...<Widget>[
                const SizedBox(height: BpSpace.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ProductThumbnail(first.imageAsset, size: 56),
                    const SizedBox(width: BpSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            first.name,
                            style: text.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (others > 0)
                            Text(
                              '+$others produk lain',
                              style: text.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: BpSpace.s3),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: BpSpace.s3,
                  children: <Widget>[
                    Text(
                      '${order.itemCount} barang',
                      style: text.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      rupiah(order.total),
                      style: text.bpPrice.copyWith(color: scheme.secondary),
                    ),
                  ],
                ),
              ),
              if (shipped) ...<Widget>[
                const Divider(height: BpSpace.s6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.touch_app_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: BpSpace.s2),
                    Expanded(
                      child: Text(
                        'Sudah sampai? Buka untuk tekan Pesanan Diterima',
                        style: text.bodyMedium!.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.primary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
