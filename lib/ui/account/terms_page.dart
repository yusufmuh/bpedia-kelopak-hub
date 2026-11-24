import 'package:daily_checkin/daily_checkin.dart' show CheckInRules;
import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart' show MissionStage;

import '../../core/assets.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/ledger.dart' show rupiahPerKelopak;
import '../../domain/rewards_engine.dart' show kelopakCapRule;
import '../widgets/widgets.dart';
import 'account_widgets.dart';

/// Akun > Syarat & Ketentuan Program.
///
/// Numbers come from the same rules and campaign configuration the games
/// use, so the terms always match what the app does.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sections = <_TermsSection>[
      _kelopakSection(),
      _checkInSection(),
      _wheelSection(app),
      _missionSection(app.missionStages),
      _demoSection(),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context, 'Syarat & Ketentuan'),
        title: const PageTitle('Syarat & Ketentuan'),
      ),
      body: AccountListView(
        children: <Widget>[
          const _TermsIntro(),
          for (final section in sections) ...<Widget>[
            const SizedBox(height: BpSpace.s6),
            SectionHeader(section.title),
            const SizedBox(height: BpSpace.s2),
            _TermsCard(points: section.points),
          ],
        ],
      ),
    );
  }

  _TermsSection _kelopakSection() {
    return _TermsSection('Kelopak', <String>[
      '1 Kelopak = ${rupiah(rupiahPerKelopak)}. Kelopak selalu bilangan '
          'bulat dan saldonya tidak pernah minus.',
      'Kelopak didapat dari Check-in Harian dan Roda Sabtu.',
      'Saat checkout, Kelopak bisa dipakai sebagai potongan. '
          '$kelopakCapRule.',
      'Setiap Kelopak yang masuk dan terpakai tercatat di Riwayat Kelopak.',
    ]);
  }

  _TermsSection _checkInSection() {
    const daily = CheckInRules.dailyKelopak;
    const every = CheckInRules.bonusEvery;
    const bonus = CheckInRules.bonusKelopak;
    const product = CheckInRules.productEvery;
    const weekTotal = every * daily + bonus;
    return _TermsSection('Check-in Harian', <String>[
      'Dapat +$daily Kelopak untuk setiap tanggal, satu kali per tanggal. '
          'Tanggal berganti pukul 00.00 WIB.',
      'Bonus +$bonus Kelopak di hari ke-$every, ${every * 2}, ${every * 3}, '
          'dan seterusnya selama beruntun. $every hari beruntun = '
          '${kelopakWithRupiah(weekTotal)}.',
      '1 hak produk gratis di hari ke-$product, ${product * 2}, dan '
          'seterusnya selama beruntun.',
      'Bolong 1 tanggal membuat rentetan mulai lagi dari Hari 1. Kelopak '
          'dan hak produk yang sudah didapat tetap aman.',
    ]);
  }

  _TermsSection _wheelSection(AppState app) {
    final odds = app.spinOdds
        .map((entry) => '${entry.prize.label} ${entry.percentText}')
        .join(', ');
    return _TermsSection('Roda Sabtu', <String>[
      'Penyelenggara: Bpedia. Gratis, tanpa syarat pembelian.',
      '1 putaran per akun setiap Sabtu, pukul 00.00 sampai 23.59 WIB, '
          'selama promo berlangsung.',
      'Peluang saat ini: $odds.',
      'Sisa kuota produk: ${app.productStock}.',
      'Ongkir hadiah produk: ${app.spinConfig.shippingNote}.',
      'Bila kuota produk habis, peluang produk menjadi 0% dan setiap '
          'putaran berhadiah Kelopak.',
      'Peluang, sisa kuota, dan ongkir selalu tampil sebelum tombol Putar '
          'gratis.',
      'Hasil ditentukan sistem saat tombol Putar gratis ditekan. Animasi '
          'roda hanya menampilkan hasil itu.',
      'Apple bukan sponsor dan tidak terlibat dalam promosi ini.',
      'Google bukan sponsor dan tidak terlibat dalam promosi ini.',
    ]);
  }

  _TermsSection _missionSection(List<MissionStage> stages) {
    final validDays = stages.map((stage) => stage.voucherValidDays).toSet();
    final validity = validDays.length == 1
        ? 'Voucher berlaku sampai ${validDays.single} hari setelah terbit '
              '(Demo)'
        : 'Masa berlaku voucher mengikuti tahapnya (Demo)';
    return _TermsSection('Misi Belanja', <String>[
      for (final stage in stages)
        'Tahap ${stage.number}${stage.number > 1 ? ' (Demo)' : ''}: '
            'selesaikan 1 pesanan dengan subtotal barang min. '
            '${rupiah(stage.minOrderSubtotal)}. Hadiahnya voucher '
            '${rupiah(stage.voucherAmount)} untuk pesanan berikutnya dengan '
            'min. belanja ${rupiah(stage.voucherMinSpend)}.',
      'Tahap berikutnya terbuka setelah voucher tahap sebelumnya terbit. '
          'Sesudah tahap terakhir, tahap baru menunggu kampanye berikutnya.',
      'Hanya pesanan berstatus Selesai yang dihitung, dan satu pesanan '
          'hanya dihitung sekali.',
      'Subtotal barang dihitung sebelum potongan voucher dan Kelopak.',
      '$validity dan tidak bisa dipakai di pesanan yang menerbitkannya.',
    ]);
  }

  _TermsSection _demoSection() {
    return const _TermsSection('Mode Demo', <String>[
      '${AppConfig.appName} adalah prototipe. Saldo, pesanan, voucher, dan '
          'hadiah adalah data simulasi yang tersimpan di perangkat ini.',
      'Data demo tidak bernilai uang, tidak bisa ditukar, dan tidak '
          'terhubung ke akun Bpedia resmi.',
      'Pembayaran hanya simulasi dan tidak ada barang yang dikirim.',
      'Nilai bertanda (Demo) masih menunggu keputusan bisnis dan bisa '
          'berubah.',
      'Menghapus aplikasi atau memakai Reset semua data di Mode Demo (QA) '
          'menghapus data ini.',
    ]);
  }
}

class _TermsSection {
  const _TermsSection(this.title, this.points);

  final String title;
  final List<String> points;
}

class _TermsIntro extends StatelessWidget {
  const _TermsIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Aturan program Kelopak',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: BpSpace.s1),
                Text(
                  'Berlaku untuk Check-in Harian, Roda Sabtu, dan Misi '
                  'Belanja. Nilai bertanda (Demo) masih bisa berubah.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BpSpace.s3),
          Image.asset(
            AppImages.bipySenyum,
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(width: 72, height: 72),
          ),
        ],
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.points});

  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < points.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: BpSpace.s3),
            _TermsPoint(points[i]),
          ],
        ],
      ),
    );
  }
}

class _TermsPoint extends StatelessWidget {
  const _TermsPoint(this.text);

  final String text;

  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium!;
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize! * (style.height ?? 1.4));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: (lineHeight - _dot) / 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: _dot),
          ),
        ),
        const SizedBox(width: BpSpace.s3),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
