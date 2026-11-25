/// Keadaan Kelopak seorang pengguna: potret tak-berubah yang disimpan dan
/// dikirim server (Dart murni).
library;

import '../storage/json_reader.dart';
import 'checkout.dart';
import 'gifts.dart';
import 'ledger.dart';
import 'voucher.dart';

/// Hasil tersimpan satu putaran Roda Sabtu.
///
/// [landingSeed] dan [productStockBefore] membuat roda menampilkan irisan
/// dan sudut berhenti yang sama setelah aplikasi dibuka ulang.
final class SpinRecord {
  const SpinRecord({
    required this.wibDay,
    required this.prizeId,
    required this.roll,
    required this.landingSeed,
    required this.configVersion,
    this.productStockBefore,
    this.giftId,
  });

  /// Memulihkan catatan hasil [toJson].
  factory SpinRecord.fromJson(Object? source) {
    final json = asJsonMap(source, 'spin record');
    return SpinRecord(
      wibDay: readInt(json, 'wibDay'),
      prizeId: readString(json, 'prizeId'),
      roll: readInt(json, 'roll'),
      landingSeed: readInt(json, 'landingSeed'),
      configVersion: readString(json, 'configVersion'),
      productStockBefore: readOptionalInt(json, 'productStockBefore'),
      giftId: readOptionalString(json, 'giftId'),
    );
  }

  /// Hari WIB (Sabtu) putaran.
  final int wibDay;

  /// ID hadiah yang dimenangkan.
  final String prizeId;

  /// Angka acak 0..9999 penentu hadiah.
  final int roll;

  /// Benih posisi berhenti roda di dalam irisan pemenang.
  final int landingSeed;

  /// `SpinConfig.version` yang dipakai.
  final String configVersion;

  /// Sisa kuota produk tepat sebelum putaran, penentu irisan roda. Null hanya
  /// pada dokumen lama yang belum menyimpannya.
  final int? productStockBefore;

  /// Hadiah menunggu yang dibuat putaran ini (menang produk), atau null.
  final String? giftId;

  /// Menyerialkan catatan.
  Map<String, Object?> toJson() => <String, Object?>{
    'wibDay': wibDay,
    'prizeId': prizeId,
    'roll': roll,
    'landingSeed': landingSeed,
    'configVersion': configVersion,
    'productStockBefore': productStockBefore,
    'giftId': giftId,
  };

  @override
  bool operator ==(Object other) =>
      other is SpinRecord &&
      other.wibDay == wibDay &&
      other.prizeId == prizeId &&
      other.roll == roll &&
      other.landingSeed == landingSeed &&
      other.configVersion == configVersion &&
      other.productStockBefore == productStockBefore &&
      other.giftId == giftId;

  @override
  int get hashCode => Object.hash(
    wibDay,
    prizeId,
    roll,
    landingSeed,
    configVersion,
    productStockBefore,
    giftId,
  );
}

/// Potret tak-berubah seluruh data hadiah. Semua koleksi tidak bisa diubah.
final class KelopakState {
  KelopakState({
    List<LedgerEntry> ledger = const <LedgerEntry>[],
    this.streak = 0,
    this.lastClaimDay,
    List<PendingGift> gifts = const <PendingGift>[],
    List<SpinRecord> spins = const <SpinRecord>[],
    this.promoActive = true,
    this.wheelQuotaUsed = 0,
    this.wheelQuotaWeek,
    this.missionIssuedCount = 0,
    Set<String> countedOrderIds = const <String>{},
    List<KelopakVoucher> vouchers = const <KelopakVoucher>[],
    List<KelopakOrder> orders = const <KelopakOrder>[],
    this.ledgerSeq = 0,
    this.giftSeq = 0,
    this.voucherSeq = 0,
  }) : ledger = List<LedgerEntry>.unmodifiable(ledger),
       gifts = List<PendingGift>.unmodifiable(gifts),
       spins = List<SpinRecord>.unmodifiable(spins),
       countedOrderIds = Set<String>.unmodifiable(countedOrderIds),
       vouchers = List<KelopakVoucher>.unmodifiable(vouchers),
       orders = List<KelopakOrder>.unmodifiable(orders);

  /// Memulihkan keadaan hasil [toJson].
  ///
  /// Melempar [FormatException] untuk tipe yang salah, pencacah negatif,
  /// saldo negatif, atau ID ganda. Kunci yang hilang memakai nilai keadaan
  /// baru.
  factory KelopakState.fromJson(Object? source) {
    final json = asJsonMap(source, 'kelopak state');
    final state = KelopakState(
      ledger: readList(json, 'ledger', LedgerEntry.fromJson),
      streak: readInt(json, 'streak', fallback: 0),
      lastClaimDay: readOptionalInt(json, 'lastClaimDay'),
      gifts: readList(json, 'gifts', PendingGift.fromJson),
      spins: readList(json, 'spins', SpinRecord.fromJson),
      promoActive: readBool(json, 'promoActive', fallback: true),
      wheelQuotaUsed: readInt(json, 'wheelQuotaUsed', fallback: 0),
      wheelQuotaWeek: readOptionalInt(json, 'wheelQuotaWeek'),
      missionIssuedCount: readInt(json, 'missionIssuedCount', fallback: 0),
      countedOrderIds: readStringList(json, 'countedOrderIds').toSet(),
      vouchers: readList(json, 'vouchers', KelopakVoucher.fromJson),
      orders: readList(json, 'orders', KelopakOrder.fromJson),
      ledgerSeq: readInt(json, 'ledgerSeq', fallback: 0),
      giftSeq: readInt(json, 'giftSeq', fallback: 0),
      voucherSeq: readInt(json, 'voucherSeq', fallback: 0),
    );
    state.validate();
    return state;
  }

  /// Buku besar berurutan waktu (terlama lebih dulu).
  final List<LedgerEntry> ledger;

  /// Rentetan check-in tersimpan (nilai hidup: `KelopakView.liveStreak`).
  final int streak;

  /// Hari WIB check-in terakhir, null sebelum yang pertama.
  final int? lastClaimDay;

  /// Semua hadiah produk gratis, terlama lebih dulu.
  final List<PendingGift> gifts;

  /// Riwayat putaran, terlama lebih dulu.
  final List<SpinRecord> spins;

  /// Apakah promo Roda Sabtu berjalan (sakelar Mode Demo).
  final bool promoActive;

  /// Hadiah produk roda yang sudah keluar pada pekan [wheelQuotaWeek] (atau
  /// selama kampanye bila kuota tidak terisi mingguan).
  final int wheelQuotaUsed;

  /// Pekan yang dihitung [wheelQuotaUsed]; null sebelum ada yang keluar.
  final int? wheelQuotaWeek;

  /// Jumlah voucher misi yang terbit (= tahap misi yang selesai).
  final int missionIssuedCount;

  /// Pesanan yang sudah dievaluasi Misi Belanja.
  final Set<String> countedOrderIds;

  /// Voucher misi dan promo, terlama lebih dulu.
  final List<KelopakVoucher> vouchers;

  /// Pesanan yang dikomit, terlama lebih dulu.
  final List<KelopakOrder> orders;

  /// Nomor urut buku besar terakhir.
  final int ledgerSeq;

  /// Nomor urut hadiah terakhir.
  final int giftSeq;

  /// Nomor urut voucher terakhir.
  final int voucherSeq;

  /// Saldo Kelopak.
  int get balance => ledgerBalance(ledger);

  /// Melempar [FormatException] bila keadaan mustahil.
  void validate() {
    final counters = <int>[
      streak,
      wheelQuotaUsed,
      missionIssuedCount,
      ledgerSeq,
      giftSeq,
      voucherSeq,
    ];
    if (counters.any((value) => value < 0)) {
      throw const FormatException('Negative counter in Kelopak state');
    }
    if (balance < 0) throw const FormatException('Negative Kelopak balance');
    bool unique(Iterable<String> ids) => ids.toSet().length == ids.length;
    if (!unique(ledger.map((entry) => entry.id)) ||
        !unique(gifts.map((gift) => gift.id)) ||
        !unique(vouchers.map((voucher) => voucher.id)) ||
        !unique(orders.map((order) => order.id))) {
      throw const FormatException('Duplicate id in Kelopak state');
    }
  }

  /// Salinan dengan bidang yang diberikan diganti.
  KelopakState copyWith({
    List<LedgerEntry>? ledger,
    int? streak,
    int? lastClaimDay,
    List<PendingGift>? gifts,
    List<SpinRecord>? spins,
    bool? promoActive,
    int? wheelQuotaUsed,
    int? wheelQuotaWeek,
    int? missionIssuedCount,
    Set<String>? countedOrderIds,
    List<KelopakVoucher>? vouchers,
    List<KelopakOrder>? orders,
    int? ledgerSeq,
    int? giftSeq,
    int? voucherSeq,
  }) {
    return KelopakState(
      ledger: ledger ?? this.ledger,
      streak: streak ?? this.streak,
      lastClaimDay: lastClaimDay ?? this.lastClaimDay,
      gifts: gifts ?? this.gifts,
      spins: spins ?? this.spins,
      promoActive: promoActive ?? this.promoActive,
      wheelQuotaUsed: wheelQuotaUsed ?? this.wheelQuotaUsed,
      wheelQuotaWeek: wheelQuotaWeek ?? this.wheelQuotaWeek,
      missionIssuedCount: missionIssuedCount ?? this.missionIssuedCount,
      countedOrderIds: countedOrderIds ?? this.countedOrderIds,
      vouchers: vouchers ?? this.vouchers,
      orders: orders ?? this.orders,
      ledgerSeq: ledgerSeq ?? this.ledgerSeq,
      giftSeq: giftSeq ?? this.giftSeq,
      voucherSeq: voucherSeq ?? this.voucherSeq,
    );
  }

  /// Menyerialkan keadaan (ID pesanan diurutkan supaya dokumen stabil).
  Map<String, Object?> toJson() => <String, Object?>{
    'ledger': ledger.map((entry) => entry.toJson()).toList(),
    'streak': streak,
    'lastClaimDay': lastClaimDay,
    'gifts': gifts.map((gift) => gift.toJson()).toList(),
    'spins': spins.map((record) => record.toJson()).toList(),
    'promoActive': promoActive,
    'wheelQuotaUsed': wheelQuotaUsed,
    'wheelQuotaWeek': wheelQuotaWeek,
    'missionIssuedCount': missionIssuedCount,
    'countedOrderIds': countedOrderIds.toList()..sort(),
    'vouchers': vouchers.map((voucher) => voucher.toJson()).toList(),
    'orders': orders.map((order) => order.toJson()).toList(),
    'ledgerSeq': ledgerSeq,
    'giftSeq': giftSeq,
    'voucherSeq': voucherSeq,
  };
}
