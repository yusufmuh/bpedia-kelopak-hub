/// Lembar "Cara pakai": aturan Kelopak dan tiga game dalam satu tempat.
library;

import 'package:daily_checkin/daily_checkin.dart' show CheckInRules;
import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../games/game_actions.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';

/// Membuka lembar "Cara pakai". [focus] membuka bagian game itu lebih dulu.
Future<void> showKelopakHowTo(BuildContext context, {KelopakGame? focus}) {
  final controller = KelopakScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scroll) => KelopakHowTo(
        controller: controller,
        focus: focus,
        scrollController: scroll,
      ),
    ),
  );
}

/// Isi lembar "Cara pakai" (bisa juga ditanam di halaman lain).
class KelopakHowTo extends StatelessWidget {
  /// Membuat isi aturan dari [controller].
  const KelopakHowTo({
    super.key,
    required this.controller,
    this.focus,
    this.scrollController,
  });

  /// Sumber nilai kampanye.
  final KelopakController controller;

  /// Game yang ditampilkan lebih dulu.
  final KelopakGame? focus;

  /// Pengendali gulir dari lembar.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final policy = controller.campaign.policy;
    final rate = rupiah(policy.rupiahPerKelopak);
    final sections = <KelopakGame, _RuleSection>{
      KelopakGame.checkIn: _RuleSection(
        art: HubArt.calendar,
        title: KelopakGame.checkIn.title,
        rules: <String>[
          'Klaim sekali sehari: +${CheckInRules.dailyKelopak} Kelopak. Hari dihitung WIB, berganti pukul 00.00.',
          'Tiap hari ke-${CheckInRules.bonusEvery} beruntun dapat bonus +${CheckInRules.bonusKelopak} Kelopak.',
          'Hari ke-${CheckInRules.productEvery} tanpa putus: 1 produk gratis yang ikut pesanan berikutnya.',
          'Lewat satu hari, rentetan mulai lagi dari hari ke-1. Kelopak yang sudah didapat tetap aman.',
        ],
      ),
      KelopakGame.wheel: _RuleSection(
        art: HubArt.wheel,
        title: KelopakGame.wheel.title,
        rules: <String>[
          '1 putaran gratis tiap Sabtu (WIB) selama promo berjalan.',
          'Hadiah dan peluang putaran saat ini:',
          for (final odds in controller.spinOdds)
            '${odds.prize.label}: ${odds.percentText}',
          'Hadiah produk terbatas ${controller.campaign.wheelQuota} per minggu. Bila habis, peluangnya pindah ke hadiah Kelopak.',
          'Produk gratis dikirim bersama pesanan belanja berikutnya.',
        ],
      ),
      KelopakGame.mission: _RuleSection(
        art: HubArt.bag,
        title: KelopakGame.mission.title,
        rules: <String>[
          for (final stage in controller.missionStages)
            '${stage.title}: belanja produk misi minimal ${rupiah(stage.minOrderSubtotal)} dalam satu pesanan, dapat voucher ${rupiah(stage.voucherAmount)} (min. belanja ${rupiah(stage.voucherMinSpend)}, berlaku ${stage.voucherValidDays} hari).',
          'Yang dihitung hanya subtotal produk misi, dan hanya setelah pesanan diterima.',
          'Satu pesanan menyelesaikan satu tahap. Pesanan batal tidak dihitung.',
        ],
      ),
    };
    final order = <KelopakGame>[
      ?focus,
      for (final game in KelopakGame.values)
        if (game != focus) game,
    ];
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            'Cara pakai Kelopak',
            style: TextStyle(
              fontSize: 20,
              height: 26 / 20,
              fontWeight: FontWeight.w700,
              color: tones.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tones.goldTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Image(image: HubArt.coin, width: 44, height: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '1 Kelopak = $rate. Saat checkout, Kelopak otomatis memotong '
                    'harga barang setelah voucher. Kamu bisa mematikannya di '
                    'halaman checkout. Ongkir tetap dibayar.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: tones.onGoldTint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final game in order) sections[game]!,
        const SizedBox(height: 8),
        Text(
          'Hadiah produk butuh minimal 1 produk berbayar di pesanan. Bila '
          'pesanan dibatalkan, Kelopak, voucher, dan hadiah kembali ke akunmu.',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: tones.textMuted,
          ),
        ),
      ],
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.art,
    required this.title,
    required this.rules,
  });

  final ImageProvider art;
  final String title;
  final List<String> rules;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Image(image: art, width: 36, height: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tones.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10, left: 4),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tones.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule,
                      style: TextStyle(
                        fontSize: 13,
                        height: 19 / 13,
                        color: tones.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
