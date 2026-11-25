/// Riwayat Kelopak (`/hadiah/riwayat`): ringkasan saldo, saring masuk/keluar,
/// dan baris per bulan dengan saldo berjalan.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDateOf;
import 'package:flutter/material.dart';

import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/ledger.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'kelopak_navigation.dart';

/// Saringan riwayat.
enum LedgerFilter {
  /// Semua entri.
  all('Semua'),

  /// Hanya Kelopak masuk.
  earned('Didapat'),

  /// Hanya Kelopak keluar.
  spent('Dipakai');

  const LedgerFilter(this.label);

  /// Label chip.
  final String label;

  /// Apakah [entry] lolos saringan.
  bool accepts(LedgerEntry entry) => switch (this) {
    LedgerFilter.all => true,
    LedgerFilter.earned => entry.isCredit,
    LedgerFilter.spent => !entry.isCredit,
  };
}

const List<String> _monthNames = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Halaman riwayat Kelopak. Membaca `KelopakScope` terdekat.
class LedgerPage extends StatefulWidget {
  /// Membuat halaman.
  const LedgerPage({super.key, this.initialFilter = LedgerFilter.all});

  /// Saringan awal.
  final LedgerFilter initialFilter;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late LedgerFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    final Widget body;
    if (!c.isLoggedIn) {
      body = Center(
        child: SingleChildScrollView(
          child: HubEmptyState(
            title: 'Masuk dulu, Babes',
            message: 'Riwayat Kelopak tersimpan di akunmu.',
            actionLabel: 'Masuk',
            onAction: c.ensureLoggedIn,
          ),
        ),
      );
    } else {
      final all = c.ledgerHistory;
      var earned = 0;
      var spent = 0;
      for (final line in all) {
        final amount = line.entry.amount;
        if (amount > 0) {
          earned += amount;
        } else {
          spent -= amount;
        }
      }
      final lines = all.where((line) => _filter.accepts(line.entry)).toList();
      final slivers = <Widget>[
        SliverToBoxAdapter(
          child: _Summary(balance: c.balance, earned: earned, spent: spent),
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: tones.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final filter in LedgerFilter.values)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: filter == _filter,
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: filter == _filter
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: filter == _filter
                            ? tones.brandStrong
                            : tones.text,
                      ),
                      side: BorderSide(
                        color: filter == _filter ? tones.brandLine : tones.line,
                      ),
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
            ),
          ),
        ),
      ];
      if (lines.isEmpty) {
        slivers.add(
          SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(
              color: tones.surface,
              child: HubEmptyState(
                title: all.isEmpty ? 'Belum ada riwayat' : 'Belum ada entri',
                message: all.isEmpty
                    ? 'Check-in hari ini untuk Kelopak pertamamu.'
                    : 'Belum ada Kelopak yang ${_filter == LedgerFilter.spent ? 'dipakai' : 'didapat'}.',
                actionLabel: 'Check-in sekarang',
                onAction: () =>
                    KelopakNavigation.openPath(context, KelopakPaths.checkIn),
              ),
            ),
          ),
        );
      } else {
        String? month;
        final children = <Widget>[];
        for (final line in lines) {
          final date = wibDateOf(line.entry.wibDay);
          final label = '${_monthNames[date.month - 1]} ${date.year}';
          if (label != month) {
            month = label;
            children.add(_MonthHeader(label: label));
          } else {
            children.add(Divider(height: 1, indent: 68, color: tones.line));
          }
          children.add(
            ColoredBox(
              color: tones.surface,
              child: LedgerTile(line: line, showBalance: true),
            ),
          );
        }
        slivers
          ..add(SliverList.list(children: children))
          ..add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Text(
                  'Kelopak tidak kedaluwarsa selama program berjalan. Kelopak '
                  'yang dipakai di pesanan batal dikembalikan otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: tones.textMuted,
                  ),
                ),
              ),
            ),
          );
      }
      body = CustomScrollView(slivers: slivers);
    }
    return Scaffold(
      backgroundColor: tones.canvas,
      appBar: AppBar(title: const Text('Riwayat Kelopak')),
      body: body,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.balance,
    required this.earned,
    required this.spent,
  });

  final int balance;
  final int earned;
  final int spent;

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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Image(image: HubArt.coin, width: 48, height: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label:
                            'Saldo ${kelopakLabel(balance)}, senilai ${kelopakRupiah(balance)}',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Saldo Kelopak',
                              style: TextStyle(
                                fontSize: 12,
                                color: tones.onGoldTint,
                              ),
                            ),
                            Text(
                              kelopakLabel(balance),
                              style: TextStyle(
                                fontSize: 22,
                                height: 28 / 22,
                                fontWeight: FontWeight.w800,
                                color: tones.text,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                            Text(
                              'senilai ${kelopakRupiah(balance)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tones.onGoldTint,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Stat(
                        label: 'Total didapat',
                        value: '+${groupThousands(earned)}',
                        color: tones.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Stat(
                        label: 'Total dipakai',
                        value: groupThousands(spent),
                        color: tones.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tones.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 12, color: tones.textMuted)),
            Text(
              '$value Kelopak',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return ColoredBox(
      color: tones.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Semantics(
          header: true,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tones.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
