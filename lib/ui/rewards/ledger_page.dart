import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/ledger.dart';
import '../widgets/widgets.dart';
import 'checkin_page.dart';
import 'rewards_widgets.dart';

/// Riwayat Kelopak: every credit and debit grouped by WIB date (newest first)
/// with the running balance.
class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final history = app.ledgerHistory;
    const title = 'Riwayat Kelopak';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context, title),
        title: const PageTitle(title),
        actions: demoAppBarActions(context),
      ),
      body: SafeArea(
        top: false,
        child: history.isEmpty
            ? ScrollableCenter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: BpSpace.s4),
                      child: DemoBodyChip(),
                    ),
                    EmptyState(
                      imageAsset: AppImages.bipyNgintip,
                      title: 'Belum ada Kelopak',
                      body:
                          'Check-in hari ini dan Kelopak pertamamu langsung '
                          'masuk.',
                      actionLabel: 'Ambil Kelopak pertamamu',
                      onAction: () =>
                          openRewardsPage(context, const CheckInPage()),
                    ),
                  ],
                ),
              )
            : _LedgerList(balance: app.balance, groups: _groupByDay(history)),
      ),
    );
  }
}

/// Ledger lines of one WIB date.
final class _DayGroup {
  _DayGroup(this.wibDay);

  final int wibDay;
  final List<LedgerLine> lines = <LedgerLine>[];
}

/// Groups consecutive lines of the newest-first history by WIB date.
List<_DayGroup> _groupByDay(List<LedgerLine> history) {
  final groups = <_DayGroup>[];
  for (final line in history) {
    if (groups.isEmpty || groups.last.wibDay != line.entry.wibDay) {
      groups.add(_DayGroup(line.entry.wibDay));
    }
    groups.last.lines.add(line);
  }
  return groups;
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.balance, required this.groups});

  final int balance;
  final List<_DayGroup> groups;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            BpSpace.s2,
            BpSpace.s4,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: RewardsContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoBodyChip(),
                  _BalanceSummary(balance: balance),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            0,
            BpSpace.s4,
            BpSpace.s8,
          ),
          sliver: SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) =>
                RewardsContent(child: _DayGroupView(group: groups[index])),
          ),
        ),
      ],
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Saldo sekarang', style: caption),
          const SizedBox(height: BpSpace.s1),
          KelopakAmount(balance),
          const SizedBox(height: BpSpace.s1),
          Text('1 Kelopak = ${rupiah(rupiahPerKelopak)}', style: caption),
        ],
      ),
    );
  }
}

class _DayGroupView extends StatelessWidget {
  const _DayGroupView({required this.group});

  final _DayGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (var index = 0; index < group.lines.length; index++) {
      if (index > 0) rows.add(const Divider(indent: BpSpace.s4));
      rows.add(_LedgerRow(line: group.lines[index]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: BpSpace.s6,
            bottom: BpSpace.s2,
            left: BpSpace.s1,
          ),
          child: Semantics(
            header: true,
            child: Text(
              wibDateLabel(group.wibDay),
              style: theme.textTheme.titleSmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: BpSpace.s1),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.line});

  final LedgerLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = line.entry;
    final credit = entry.isCredit;
    final title = entry.note.isEmpty ? entry.kind.label : entry.note;
    final amount = Text(
      signedKelopakLabel(entry.amount),
      style: theme.textTheme.titleSmall!.copyWith(
        fontWeight: FontWeight.w700,
        color: credit ? BpColors.of(context).success700 : scheme.onSurface,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${entry.kind.label} · saldo ${kelopakLabel(line.balanceAfter)}',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final stacked = isLargeText(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BpSpace.s4,
          vertical: BpSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _KindIcon(kind: entry.kind),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        details,
                        const SizedBox(height: BpSpace.s1),
                        amount,
                      ],
                    )
                  : details,
            ),
            if (!stacked) ...<Widget>[
              const SizedBox(width: BpSpace.s3),
              amount,
            ],
          ],
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final LedgerKind kind;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      LedgerKind.checkIn => Icons.local_florist_rounded,
      LedgerKind.checkInBonus => Icons.card_giftcard_rounded,
      LedgerKind.spinPrize => Icons.auto_awesome_rounded,
      LedgerKind.checkoutSpend => Icons.shopping_bag_outlined,
    };
    return RewardIconBadge(
      size: 40,
      child: Icon(
        icon,
        size: 20,
        color: kind == LedgerKind.checkoutSpend
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
