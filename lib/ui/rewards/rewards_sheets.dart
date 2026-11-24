/// "Cara kerja" and "Syarat & ketentuan" sheets of the Hadiah screens.
///
/// Every number comes from the rule constants and the live configuration
/// (check-in rules, spin config, mission stages), so the copy never drifts
/// from what the engines do.
library;

import 'package:daily_checkin/daily_checkin.dart' show CheckInRules;
import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show SpinOdds, effectiveOdds;

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../domain/app_state.dart';
import '../../domain/ledger.dart' show rupiahPerKelopak;
import '../../domain/rewards_engine.dart' show kelopakCapRule;
import 'rewards_widgets.dart';

/// "7, 14, 21, …" for [every].
String _multiplesLabel(int every) => '$every, ${every * 2}, ${every * 3}, …';

/// Total Kelopak after [day] unbroken check-in days.
int checkInTotalKelopak(int day) =>
    day * CheckInRules.dailyKelopak +
    (day ~/ CheckInRules.bonusEvery) * CheckInRules.bonusKelopak;

String _checkInExample(int day) {
  final total = kelopakWithRupiah(checkInTotalKelopak(day));
  final products = day ~/ CheckInRules.productEvery;
  return products > 0 ? '$total + $products produk gratis' : total;
}

String _oddsSummary(List<SpinOdds> odds) =>
    odds.map((entry) => '${entry.prize.label} ${entry.percentText}').join(', ');

/// Hub footer: how Kelopak is earned and used.
Future<void> showKelopakRulesSheet(BuildContext context) {
  return showRewardsInfoSheet(
    context,
    title: 'Cara kerja Kelopak',
    imageAsset: AppImages.bipyBerdiri,
    children: <Widget>[
      Text(
        'Kumpulkan Kelopak dari tiga game, lalu pakai sebagai potongan saat '
        'checkout.',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      RulesTable(
        rows: <RuleRow>[
          RuleRow('Nilai', '1 Kelopak = ${rupiah(rupiahPerKelopak)}'),
          RuleRow(
            'Check-in Harian',
            '+${kelopakLabel(CheckInRules.dailyKelopak)} per hari',
          ),
          RuleRow(
            'Hari ke-${_multiplesLabel(CheckInRules.bonusEvery)} beruntun',
            'Bonus +${kelopakLabel(CheckInRules.bonusKelopak)}',
          ),
          const RuleRow(
            'Hari ke-${CheckInRules.productEvery} beruntun',
            '1 produk gratis',
          ),
          const RuleRow(
            'Roda Sabtu',
            '1x putar gratis tiap Sabtu: produk atau Kelopak',
          ),
          const RuleRow('Misi Belanja', 'Voucher untuk belanja berikutnya'),
          const RuleRow('Pakai di checkout', kelopakCapRule),
        ],
      ),
      const SizedBox(height: 16),
      const RuleBullet('Hari berganti pukul 00.00 WIB.'),
      const RuleBullet(
        'Bolong check-in hanya mengulang rentetan. Saldo Kelopak tetap aman.',
      ),
      const RuleBullet('Saldo Kelopak tidak pernah minus.'),
      const RuleBullet('Mode Demo: semua data tersimpan di perangkat ini.'),
    ],
  );
}

/// Check-in Harian: full rules and the example table.
Future<void> showCheckInRulesSheet(BuildContext context) {
  return showRewardsInfoSheet(
    context,
    title: 'Cara kerja Check-in Harian',
    imageAsset: AppImages.bipyBerdiri,
    children: <Widget>[
      RuleBullet(
        'Ambil ${kelopakLabel(CheckInRules.dailyKelopak)} sekali per tanggal. '
        'Hari berganti pukul 00.00 WIB.',
      ),
      RuleBullet(
        'Hari ke-${_multiplesLabel(CheckInRules.bonusEvery)} beruntun: bonus '
        '+${kelopakLabel(CheckInRules.bonusKelopak)}.',
      ),
      RuleBullet(
        'Hari ke-${_multiplesLabel(CheckInRules.productEvery)} beruntun: '
        '1 produk gratis masuk ke Hadiahku.',
      ),
      const RuleBullet(
        'Bolong 1 hari? Rentetan mulai lagi dari Hari 1. Kelopak dan hadiah '
        'yang sudah kamu dapat tetap aman.',
      ),
      const RuleHeading('Contoh kalau check-in tanpa bolong'),
      RulesTable(
        labelFlex: 3,
        valueFlex: 7,
        header: const RuleRow('Hari', 'Total yang kamu dapat'),
        rows: <RuleRow>[
          for (final day in <int>[
            1,
            CheckInRules.bonusEvery,
            CheckInRules.bonusEvery * 2,
            CheckInRules.productEvery,
          ])
            RuleRow('Hari $day', _checkInExample(day)),
        ],
      ),
    ],
  );
}

/// Roda Sabtu: terms, odds and the platform disclaimers.
Future<void> showWheelTermsSheet(BuildContext context) {
  final config = AppScope.read(context).spinConfig;
  final withStock = _oddsSummary(effectiveOdds(config, productStock: 1));
  final withoutStock = _oddsSummary(effectiveOdds(config, productStock: 0));
  return showRewardsInfoSheet(
    context,
    title: 'Syarat & ketentuan Roda Sabtu',
    imageAsset: AppImages.bipySenyum,
    children: <Widget>[
      const RuleBullet('Penyelenggara: Bpedia.'),
      const RuleBullet('Gratis, tanpa pembelian. Tidak ada putaran berbayar.'),
      const RuleBullet(
        '1x putaran per akun setiap Sabtu, 00.00–23.59 WIB, selama promo '
        'aktif.',
      ),
      RuleBullet(
        'Peluang selama kuota produk ada: $withStock. Bila kuota habis: '
        '$withoutStock.',
      ),
      const RuleBullet(
        'Peluang dan sisa kuota produk tampil di tabel sebelum tombol putar.',
      ),
      RuleBullet('Pengiriman hadiah produk: ${config.shippingNote}.'),
      const RuleBullet(
        'Hasil diacak sistem sebelum roda berputar. Animasi hanya menampilkan '
        'hasil.',
      ),
      const RuleBullet(
        'Hadiah Kelopak langsung masuk ke saldo. Produk gratis tercatat di '
        'Hadiahku.',
      ),
      const RuleBullet(
        'Apple bukan sponsor dan tidak terlibat dalam promosi ini.',
      ),
      const RuleBullet(
        'Google bukan sponsor dan tidak terlibat dalam promosi ini.',
      ),
      const RuleBullet('Mode Demo: data hanya tersimpan di perangkat ini.'),
    ],
  );
}

/// Misi Belanja: stage rules generated from the configured stages.
Future<void> showMissionTermsSheet(BuildContext context) {
  final stages = AppScope.read(context).missionStages;
  return showRewardsInfoSheet(
    context,
    title: 'Syarat & ketentuan Misi Belanja',
    imageAsset: AppImages.bipySenyum,
    children: <Widget>[
      for (var index = 0; index < stages.length; index++)
        RuleBullet(
          'Tahap ${stages[index].number}: selesaikan 1 pesanan min. '
          '${rupiah(stages[index].minOrderSubtotal)}, dapat voucher '
          '${rupiah(stages[index].voucherAmount)} (min. belanja '
          '${rupiah(stages[index].voucherMinSpend)}, berlaku '
          '${stages[index].voucherValidDays} hari).'
          '${index == 0 ? '' : ' Terbuka setelah voucher Tahap ${stages[index - 1].number} terbit.'}',
        ),
      const RuleBullet(
        'Hanya pesanan berstatus Selesai yang dihitung. Tekan Pesanan '
        'Diterima di Transaksi setelah paket sampai.',
      ),
      const RuleBullet(
        'Syarat dihitung dari subtotal barang, sebelum potongan voucher dan '
        'Kelopak.',
      ),
      const RuleBullet('Satu pesanan hanya dihitung sekali.'),
      const RuleBullet(
        'Voucher tidak bisa dipakai di pesanan yang menerbitkannya. Satu '
        'voucher untuk satu pesanan.',
      ),
      const RuleBullet(
        'Sesudah tahap terakhir, tahap berikutnya menunggu kampanye.',
      ),
      const RuleBullet(
        'Nilai tahap 2 dan masa berlaku voucher adalah nilai Demo.',
      ),
    ],
  );
}
