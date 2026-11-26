/// Riwayat Kelopak (`/hadiah/riwayat`): hero saldo, ringkasan masuk/dipakai,
/// saring Semua/Masuk/Dipakai/Hadiah, dan baris per bulan dengan saldo
/// berjalan.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDateOf;
import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/material.dart';

import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/gifts.dart';
import '../domain/ledger.dart';
import '../kit/kit.dart';
import 'hero_balance.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'kelopak_navigation.dart';

/// Saringan riwayat.
enum LedgerFilter {
  /// Semua entri, termasuk hadiah produk.
  all('Semua'),

  /// Hanya Kelopak masuk.
  earned('Masuk'),

  /// Hanya Kelopak keluar.
  spent('Dipakai'),

  /// Hanya hadiah produk (Roda Sabtu, Check-in hari ke-30).
  gifts('Hadiah');

  const LedgerFilter(this.label);

  /// Label chip.
  final String label;

  /// Apakah [entry] lolos saringan.
  bool accepts(LedgerEntry entry) => switch (this) {
    LedgerFilter.all => true,
    LedgerFilter.earned => entry.isCredit,
    LedgerFilter.spent => !entry.isCredit,
    LedgerFilter.gifts => false,
  };

  /// Apakah hadiah produk ikut tampil.
  bool get showsGifts => this == LedgerFilter.all || this == LedgerFilter.gifts;
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

/// Satu baris tampil: entri Kelopak atau hadiah produk.
typedef _Row = ({int day, LedgerLine? line, PendingGift? gift});

class _LedgerPageState extends State<LedgerPage> {
  late LedgerFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    final loggedIn = c.isLoggedIn;
    final slivers = <Widget>[];
    if (!loggedIn) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: tones.surface,
            child: HubEmptyState(
              title: 'Masuk dulu, Babes',
              message: 'Riwayat Kelopak tersimpan di akunmu.',
              actionLabel: 'Masuk',
              onAction: c.ensureLoggedIn,
            ),
          ),
        ),
      );
    } else {
      final all = c.ledgerHistory;
      final gifts = c.gifts;
      var earned = 0;
      var spent = 0;
      int? since;
      for (final line in all) {
        final amount = line.entry.amount;
        if (amount > 0) {
          earned += amount;
        } else {
          spent -= amount;
        }
        final day = line.entry.wibDay;
        if (since == null || day < since) since = day;
      }
      final rows = <_Row>[
        for (final line in all)
          if (_filter.accepts(line.entry))
            (day: line.entry.wibDay, line: line, gift: null),
        if (_filter.showsGifts)
          for (final gift in gifts) (day: gift.wonDay, line: null, gift: gift),
      ];
      mergeSort(rows, compare: (a, b) => b.day.compareTo(a.day));
      slivers
        ..add(
          SliverToBoxAdapter(
            child: _Summary(earned: earned, spent: spent, since: since),
          ),
        )
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  for (final filter in LedgerFilter.values)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: filter == _filter,
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      shape: const StadiumBorder(),
                      selectedColor: tones.brandTint,
                      backgroundColor: tones.surface,
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
        );
      if (rows.isEmpty) {
        final nothing = all.isEmpty && gifts.isEmpty;
        slivers.add(
          SliverToBoxAdapter(
            child: HubEmptyState(
              title: nothing ? 'Belum ada riwayat' : 'Belum ada entri',
              message: nothing
                  ? 'Check-in hari ini untuk Kelopak pertamamu.'
                  : switch (_filter) {
                      LedgerFilter.spent => 'Belum ada Kelopak yang dipakai.',
                      LedgerFilter.gifts =>
                        'Belum ada hadiah produk. Coba Roda Sabtu atau '
                            'check-in sampai hari ke-30.',
                      _ => 'Belum ada Kelopak yang masuk.',
                    },
              actionLabel: 'Check-in sekarang',
              onAction: () =>
                  KelopakNavigation.openPath(context, KelopakPaths.checkIn),
            ),
          ),
        );
      } else {
        String? month;
        final children = <Widget>[];
        for (final row in rows) {
          final date = wibDateOf(row.day);
          final label = '${_monthNames[date.month - 1]} ${date.year}';
          if (label != month) {
            month = label;
            children.add(_MonthHeader(label: label));
          } else {
            children.add(
              Divider(height: 1, indent: 16, endIndent: 16, color: tones.line),
            );
          }
          final line = row.line;
          final gift = row.gift;
          children.add(
            line != null
                ? LedgerTile(line: line, showBalance: true)
                : GiftLedgerTile(gift: gift!),
          );
        }
        slivers
          ..add(SliverList.list(children: children))
          ..add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tones.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: tones.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kelopak dipakai otomatis saat checkout dan hanya '
                            'memotong harga barang, bukan ongkir. Pesanan '
                            'dibatalkan, Kelopak kembali.',
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
              ),
            ),
          );
      }
    }
    return GameScaffold(
      title: 'Riwayat Kelopak',
      showBack: Navigator.of(context).canPop(),
      heroTitleExtent: 28,
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: const Text(
              'Riwayat Kelopak',
              style: TextStyle(
                fontSize: 20,
                height: 26 / 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: heroTextShadow,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: loggedIn
                    ? HubHeroBalance(controller: c, showHistory: false)
                    : const Text(
                        'Masuk untuk melihat saldo Kelopakmu.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: heroTextShadow,
                        ),
                      ),
              ),
              const Bobbing(
                amplitude: 4,
                child: Image(image: HubArt.bipyCheer, height: 104),
              ),
            ],
          ),
        ],
      ),
      slivers: slivers,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.earned,
    required this.spent,
    required this.since,
  });

  final int earned;
  final int spent;
  final int? since;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final from = since;
    final suffix = from == null ? '' : ' sejak ${shortDateLabel(from)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _Stat(
                label: 'Masuk$suffix',
                value: '+${groupThousands(earned)} Kelopak',
                color: tones.success,
                background: tones.successTint,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: 'Dipakai$suffix',
                value: spent == 0
                    ? '0 Kelopak'
                    : '−${groupThousands(spent)} Kelopak',
                color: tones.danger,
                background: tones.scheme.errorContainer.withValues(
                  alpha: tones.dark ? 0.35 : 0.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 12, color: tones.textMuted)),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                height: 20 / 15,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
    );
  }
}
