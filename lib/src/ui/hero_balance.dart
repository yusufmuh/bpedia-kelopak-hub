/// Blok saldo Kelopak bersama untuk hero zona Hadiah dan Riwayat Kelopak.
library;

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../kit/kit.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'kelopak_navigation.dart';

/// Bayangan tipis untuk teks putih kecil di bagian hero yang paling terang.
const List<Shadow> heroTextShadow = <Shadow>[
  Shadow(color: Color(0x806B1439), offset: Offset(0, 1), blurRadius: 3),
];

/// Saldo Kelopak di hero pesta: label "Kelopakmu" (opsional dengan pil
/// Riwayat), angka besar berakhiran "Kelopak", pil senilai, dan kurs.
class HubHeroBalance extends StatelessWidget {
  /// Membuat blok saldo.
  const HubHeroBalance({
    super.key,
    required this.controller,
    this.showHistory = true,
  });

  /// Sumber saldo.
  final KelopakController controller;

  /// Tampilkan pil "Riwayat" di samping label.
  final bool showHistory;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const white = Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                'Kelopakmu',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  color: white,
                  shadows: heroTextShadow,
                ),
              ),
              if (showHistory)
                GlassChip(
                  label: 'Riwayat',
                  leading: const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: white,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: white,
                  ),
                  onTap: () =>
                      KelopakNavigation.openPath(context, KelopakPaths.ledger),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Saldo ${kelopakLabel(c.balance)}',
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                const Image(image: HubArt.coin, width: 40, height: 40),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        CountUpText(
                          value: c.balance,
                          bump: true,
                          style: const TextStyle(
                            fontSize: 36,
                            height: 42 / 36,
                            fontWeight: FontWeight.w800,
                            color: white,
                            shadows: <Shadow>[
                              Shadow(
                                color: Color(0x8C6B1439),
                                offset: Offset(0, 2),
                              ),
                              Shadow(
                                color: Color(0x596B1439),
                                offset: Offset(0, 6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Kelopak',
                          style: TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            fontWeight: FontWeight.w700,
                            color: white,
                            shadows: heroTextShadow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: FestivePalette.goldLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    'senilai ${kelopakRupiah(c.balance)}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w700,
                      color: FestivePalette.onGold,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
              ),
              Text(
                '1 Kelopak = ${rupiah(c.campaign.policy.rupiahPerKelopak)}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: white,
                  shadows: heroTextShadow,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
