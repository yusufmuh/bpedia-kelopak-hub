import 'dart:async';

import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart' show OrderRejection;

import '../../core/assets.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../data/catalog.dart';
import '../../domain/app_state.dart';
import '../../domain/shop_engine.dart';
import '../rewards/reward_copy.dart' show sharedStageNote;
import '../shop/shop_layout.dart';
import '../shop/shop_navigation.dart';
import '../widgets/widgets.dart';
import 'order_not_found.dart';
import 'order_status_pill.dart';

/// Order detail: status timeline, products, payment breakdown, the Misi
/// Belanja effect, and "Pesanan Diterima" while the order is on its way.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  /// Order to show.
  final String orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Future<void> _confirmReceived(BuildContext buttonContext) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // When the buttons do not fit side by side they stack with the
        // primary one on top, both centred.
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actionsOverflowButtonSpacing: BpSpace.s2,
        title: const Text('Pesanan sudah diterima?'),
        content: const Text(
          'Pastikan semua barang sudah sampai dengan baik. Status pesanan '
          'akan berubah menjadi Selesai.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Belum'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Ya, sudah diterima',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final origin = buttonContext.mounted ? globalCenterOf(buttonContext) : null;
    final app = AppScope.read(context);
    final completion = app.markOrderReceived(widget.orderId);
    if (completion == null) {
      app.feedback(FeedbackEvent.softError);
      showShopSnackBar(context, 'Pesanan ini sudah selesai.');
      return;
    }
    final voucher = completion.voucher;
    if (completion.decision.issued && voucher != null) {
      app.feedback(FeedbackEvent.voucherIssued);
      unawaited(
        showRewardResultSheet(
          context,
          title: 'Misi tahap ${voucher.stageNumber} selesai!',
          lines: <String>[
            'Voucher ${rupiah(voucher.amount)} sudah masuk ke Hadiahku',
            'Berlaku untuk belanja berikutnya min. ${rupiah(voucher.minSpend)}',
          ],
          imageAsset: AppImages.bipyTasHati,
          primaryLabel: 'Oke',
          secondaryLabel: 'Lihat misi',
          onSecondary: _openMissions,
        ),
      );
      PetalBurst.play(context, globalOrigin: origin);
      return;
    }
    app.feedback(FeedbackEvent.softError);
    unawaited(
      showRewardResultSheet(
        context,
        title: 'Pesanan selesai',
        lines: _rejectionLines(app, completion),
        imageAsset: AppImages.bipySenyum,
        primaryLabel: 'Oke',
        secondaryLabel: 'Lihat misi',
        onSecondary: _openMissions,
      ),
    );
  }

  void _openMissions() {
    if (mounted) openMissions(context);
  }

  static List<String> _rejectionLines(
    AppState app,
    OrderCompletion completion,
  ) {
    final stage = app.activeMissionStage;
    return switch (completion.decision.rejection) {
      OrderRejection.belowThreshold when stage != null => <String>[
        'Subtotal ${rupiah(completion.order.subtotal)} belum mencapai min. '
            '${rupiah(stage.minOrderSubtotal)} untuk Tahap ${stage.number}',
        'Belanja min. ${rupiah(stage.minOrderSubtotal)} di pesanan berikutnya '
            'untuk dapat voucher ${rupiah(stage.voucherAmount)}.',
      ],
      OrderRejection.allStagesDone => <String>[
        'Semua tahap misi demo sudah selesai',
        'Tahap berikutnya menunggu kampanye.',
      ],
      OrderRejection.alreadyCounted => <String>[
        'Pesanan ini sudah pernah dihitung untuk Misi Belanja',
      ],
      OrderRejection.belowThreshold ||
      OrderRejection.notCompleted ||
      null => <String>['Terima kasih sudah mengonfirmasi pesananmu, Babes.'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final order = app.orderById(widget.orderId);
    if (order == null) return const OrderNotFoundPage();
    final shipped = order.status == OrderStatus.shipped;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context, 'Detail pesanan'),
        title: const PageTitle('Detail pesanan'),
      ),
      body: FocusTraversalGroup(
        child: ListView(
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
                  _OrderHeader(order: order),
                  _MissionNote(order: order),
                  const SizedBox(height: BpSpace.s6),
                  const SectionHeader('Status'),
                  const SizedBox(height: BpSpace.s3),
                  SoftCard(child: _StatusTimeline(order: order)),
                  const SizedBox(height: BpSpace.s6),
                  SectionHeader('Produk (${order.itemCount})'),
                  const SizedBox(height: BpSpace.s3),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: BpSpace.s3,
                      children: <Widget>[
                        for (final line in order.lines)
                          _OrderLineTile(line: line),
                      ],
                    ),
                  ),
                  const SizedBox(height: BpSpace.s6),
                  const SectionHeader('Rincian pembayaran'),
                  const SizedBox(height: BpSpace.s3),
                  SoftCard(child: _OrderAmounts(order: order)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: shipped
          ? BottomActionBar(
              child: Builder(
                builder: (buttonContext) => FilledButton(
                  onPressed: () => unawaited(_confirmReceived(buttonContext)),
                  child: const Text(
                    'Pesanan Diterima',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'No. pesanan',
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BpSpace.s2,
              runSpacing: BpSpace.s2,
              children: <Widget>[
                Text(order.id, style: theme.textTheme.titleMedium),
                OrderStatusPill(order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What this order means for Misi Belanja, or nothing when it does not count.
class _MissionNote extends StatelessWidget {
  const _MissionNote({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final String? message;
    final issued = app.rewards.voucherFromOrder(order.id);
    final stage = app.activeMissionStage;
    if (issued != null) {
      message =
          'Pesanan ini menyelesaikan Misi Belanja tahap ${issued.stageNumber}. '
          'Voucher ${rupiah(issued.amount)} ada di Hadiahku.';
    } else if (order.status == OrderStatus.shipped && stage != null) {
      if (order.subtotal < stage.minOrderSubtotal) {
        message =
            'Subtotal pesanan ini belum mencapai min. '
            '${rupiah(stage.minOrderSubtotal)} untuk Misi Belanja tahap '
            '${stage.number}.';
      } else if (app.isOnlyOrderAwaitingMission(order)) {
        message =
            'Tekan Pesanan Diterima setelah barang sampai untuk menyelesaikan '
            'Misi Belanja tahap ${stage.number}.';
      } else {
        message = sharedStageNote(stage);
      }
    } else {
      message = null;
    }
    if (message == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: BpSpace.s3),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(BpRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BpSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const BrandIcon(BrandIcons.voucher),
                const SizedBox(width: BpSpace.s3),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onPrimaryContainer,
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

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.detail,
    required this.done,
  });

  final String title;
  final String detail;
  final bool done;
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final completedDay = order.completedDay;
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Pesanan dibuat',
        detail: wibDateLabel(order.placedDay),
        done: true,
      ),
      _TimelineStep(
        title: 'Dikirim',
        detail: 'Gratis ongkir (Demo) · ${shortDateLabel(order.placedDay)}',
        done: true,
      ),
      _TimelineStep(
        title: 'Selesai',
        detail: completedDay == null
            ? 'Tekan Pesanan Diterima setelah barang sampai'
            : wibDateLabel(completedDay),
        done: completedDay != null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            lineDone: i < steps.length - 1 && steps[i + 1].done,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.lineDone,
  });

  final _TimelineStep step;
  final bool isLast;
  final bool lineDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: '${step.title}, ${step.detail}, ${step.done ? 'sudah' : 'belum'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 24,
              child: Column(
                children: <Widget>[
                  Icon(
                    step.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 24,
                    color: step.done ? scheme.primary : scheme.outline,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SizedBox(
                          width: 2,
                          child: ColoredBox(
                            color: lineDone
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : BpSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(step.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      step.detail,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderLineTile extends StatelessWidget {
  const _OrderLineTile({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inCatalog = productById(line.productId) != null;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ProductThumbnail(line.imageAsset, size: 56),
        const SizedBox(width: BpSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                line.name,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${line.qty} × ${rupiah(line.price)}',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                rupiah(line.lineTotal),
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final label = '${line.name}, ${line.qty} barang, ${rupiah(line.lineTotal)}';
    if (!inCatalog) {
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: content),
      );
    }
    // The InkWell gives this node its tap action and keyboard focus.
    return Semantics(
      container: true,
      button: true,
      label: label,
      hint: 'Lihat produk',
      child: InkWell(
        onTap: () => openProduct(context, line.productId),
        borderRadius: BorderRadius.circular(BpRadius.sm),
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}

class _OrderAmounts extends StatelessWidget {
  const _OrderAmounts({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BpSpace.s2,
      children: <Widget>[
        AmountRow(
          label: 'Subtotal (${order.itemCount} barang)',
          value: rupiah(order.subtotal),
        ),
        if (order.voucherDiscount > 0)
          AmountRow(
            label: 'Voucher Misi Belanja',
            value: rupiah(-order.voucherDiscount),
            semanticValue: 'potongan ${rupiah(order.voucherDiscount)}',
            tone: AmountTone.saving,
          ),
        if (order.kelopakUsed > 0)
          AmountRow(
            label: 'Pakai ${kelopakLabel(order.kelopakUsed)}',
            value: rupiah(-order.kelopakDiscount),
            semanticValue: 'potongan ${rupiah(order.kelopakDiscount)}',
            tone: AmountTone.saving,
          ),
        const AmountRow(label: 'Ongkir', value: 'Gratis'),
        const Divider(height: BpSpace.s3),
        AmountRow(
          label: 'Total bayar',
          value: rupiah(order.total),
          tone: AmountTone.total,
        ),
      ],
    );
  }
}
