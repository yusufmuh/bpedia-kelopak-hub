/// Aturan tukar Kelopak dan konfigurasi kampanye hadiah (Dart murni).
///
/// Semua nilai bertanda (demo) adalah keputusan bisnis; aplikasi induk
/// menyusunnya di satu berkas konfigurasi dan menyuntikkannya ke sini.
library;

import 'package:misi_belanja/misi_belanja.dart'
    show MissionStage, demoMissionStages;
import 'package:roda_sabtu/roda_sabtu.dart'
    show PrizeKind, SpinConfig, SpinPrize, demoSpinConfig;

import '../core/units.dart' as units;

/// Nilai Kelopak dan batas pemakaiannya di checkout (KEPUTUSAN §1).
final class KelopakPolicy {
  const KelopakPolicy({
    this.rupiahPerKelopak = units.rupiahPerKelopak,
    this.redeemShareBp = fullShareBp,
  }) : assert(rupiahPerKelopak > 0, 'rupiahPerKelopak must be positive'),
       assert(
         redeemShareBp >= 0 && redeemShareBp <= fullShareBp,
         'redeemShareBp must be within 0..10000',
       );

  /// Basis poin untuk "seluruh harga barang".
  static const int fullShareBp = 10000;

  /// Rupiah per 1 Kelopak.
  final int rupiahPerKelopak;

  /// Bagian harga barang (setelah voucher) yang boleh ditutup Kelopak, dalam
  /// basis poin. (demo) 10000 = seluruhnya.
  final int redeemShareBp;

  /// Kelopak terbanyak yang boleh dipakai untuk harga barang setelah voucher
  /// [goodsAfterVoucher]: `floor(harga x bagian / nilai Kelopak)`. Pecahan di
  /// bawah satu Kelopak tetap dibayar.
  int maxKelopakFor(int goodsAfterVoucher) {
    if (goodsAfterVoucher <= 0) return 0;
    return goodsAfterVoucher * redeemShareBp ~/ fullShareBp ~/ rupiahPerKelopak;
  }

  /// Nilai rupiah [kelopak] Kelopak.
  int rupiahOf(int kelopak) => kelopak * rupiahPerKelopak;

  @override
  bool operator ==(Object other) =>
      other is KelopakPolicy &&
      other.rupiahPerKelopak == rupiahPerKelopak &&
      other.redeemShareBp == redeemShareBp;

  @override
  int get hashCode => Object.hash(rupiahPerKelopak, redeemShareBp);
}

/// Satu kampanye hadiah: aturan tukar, Roda Sabtu, Misi Belanja, dan hadiah
/// Check-in hari ke-30. Aturan Check-in Harian sendiri tetap di
/// `CheckInRules` modul `daily_checkin`.
final class KelopakCampaign {
  const KelopakCampaign({
    this.policy = const KelopakPolicy(),
    this.wheel = demoSpinConfig,
    this.wheelQuota = 3,
    this.wheelQuotaRefillsWeekly = true,
    this.wheelProductCodes = const <String>[],
    this.missionStages = demoMissionStages,
    this.checkIn30ProductCode,
  }) : assert(wheelQuota >= 0, 'wheelQuota must not be negative');

  /// Kampanye contoh (nilai demo modul, tanpa kode produk).
  static const KelopakCampaign demo = KelopakCampaign();

  /// Aturan tukar Kelopak di checkout.
  final KelopakPolicy policy;

  /// Hadiah, peluang, dan tata letak Roda Sabtu.
  final SpinConfig wheel;

  /// Kuota hadiah produk roda. (demo) 3.
  final int wheelQuota;

  /// True: kuota terisi lagi tiap pekan (Senin WIB). False: [wheelQuota]
  /// berlaku untuk seluruh kampanye.
  final bool wheelQuotaRefillsWeekly;

  /// Kode produk hadiah roda, bergilir tiap pekan. Dipakai bila hadiah
  /// produk di [wheel] tidak menyebut `productCode` sendiri.
  final List<String> wheelProductCodes;

  /// Tahap Misi Belanja berurutan, lengkap dengan kode produk misinya.
  final List<MissionStage> missionStages;

  /// Kode produk hadiah Check-in hari ke-30; null bila belum ditentukan.
  final String? checkIn30ProductCode;

  /// Nomor pekan (Senin sampai Minggu) dari hari WIB [wibDay].
  static int weekOf(int wibDay) => (wibDay + 3) ~/ DateTime.daysPerWeek;

  /// Kode produk yang dihadiahkan [prize] bila dimenangkan pada [wibDay]:
  /// kode milik hadiah itu, atau giliran pekan itu dari [wheelProductCodes].
  /// Null untuk hadiah Kelopak dan bila kampanye tidak menyebut produk.
  String? wheelProductCodeFor(SpinPrize prize, int wibDay) {
    if (prize.kind != PrizeKind.product) return null;
    final own = prize.productCode;
    if (own != null) return own;
    if (wheelProductCodes.isEmpty) return null;
    return wheelProductCodes[weekOf(wibDay) % wheelProductCodes.length];
  }

  /// Kode produk hadiah roda pada [wibDay] (hadiah produk pertama), atau null.
  String? wheelProductCodeOn(int wibDay) {
    for (final prize in wheel.prizes) {
      if (prize.kind == PrizeKind.product) {
        return wheelProductCodeFor(prize, wibDay);
      }
    }
    return null;
  }
}
