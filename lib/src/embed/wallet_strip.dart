/// Strip dompet Kelopak untuk Beranda host (SPEC-V3 §4.1 butir 2).
library;

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../kit/motion.dart';
import '../ui/hub_art.dart';
import '../ui/hub_widgets.dart';
import '../ui/kelopak_navigation.dart';

/// Tiga sel berpemisah: saldo Kelopak, voucher, hadiah menunggu. Gaya
/// netral mengikuti tema host. Membaca `KelopakScope` terdekat; tamu yang
/// mengetuk sel diarahkan ke halaman Masuk.
class KelopakWalletStrip extends StatelessWidget {
  /// Membuat strip. [margin] bawaan 16 kiri-kanan.
  const KelopakWalletStrip({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Jarak luar.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    final guest = !c.isLoggedIn;
    final balance = guest ? 0 : c.balance;
    final vouchers = guest ? 0 : c.activeVouchers.length;
    final gifts = guest ? 0 : c.pendingGifts.length;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tones.line),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 6,
                child: _Cell(
                  art: HubArt.coin,
                  value: guest || balance == 0
                      ? 'Kelopak'
                      : kelopakLabel(balance),
                  caption: guest || balance == 0
                      ? 'Kumpulkan, 1 = Rp100'
                      : 'senilai ${kelopakRupiah(balance)}',
                  emphasis: !guest && balance > 0,
                  onTap: () => _open(context, c, KelopakPaths.ledger),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: tones.line),
              Expanded(
                flex: 5,
                child: _Cell(
                  art: HubArt.ticket,
                  value: vouchers == 0 ? 'Voucher' : '$vouchers voucher',
                  caption: vouchers == 0 ? 'Dari Misi Belanja' : 'Siap dipakai',
                  emphasis: vouchers > 0,
                  onTap: () => _open(context, c, KelopakPaths.vouchers),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: tones.line),
              Expanded(
                flex: 5,
                child: _Cell(
                  art: HubArt.gift,
                  value: gifts == 0 ? 'Hadiah' : '$gifts hadiah',
                  caption: gifts == 0 ? 'Belum ada' : 'Menunggu',
                  emphasis: gifts > 0,
                  dot: gifts > 0,
                  onTap: () {
                    if (!c.ensureLoggedIn()) return;
                    if (gifts > 0) {
                      c.host?.openCart();
                    } else {
                      KelopakNavigation.openPath(context, KelopakPaths.myGifts);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, KelopakController c, String path) {
    if (!c.ensureLoggedIn()) return;
    KelopakNavigation.openPath(context, path);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.art,
    required this.value,
    required this.caption,
    required this.onTap,
    this.emphasis = false,
    this.dot = false,
  });

  final ImageProvider art;
  final String value;
  final String caption;
  final VoidCallback onTap;
  final bool emphasis;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: '$value, $caption',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Image(image: art, width: 24, height: 24),
                      if (dot)
                        const PositionedDirectional(
                          top: -3,
                          end: -3,
                          child: ReadyDot(size: 9),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 17 / 13,
                        fontWeight: FontWeight.w700,
                        color: emphasis ? tones.brandStrong : tones.text,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 14 / 11,
                  color: tones.textMuted,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
