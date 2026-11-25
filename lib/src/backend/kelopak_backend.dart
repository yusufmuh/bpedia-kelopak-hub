/// Pintu data sistem Kelopak. Mengganti demo lokal dengan server sungguhan
/// berarti mengganti satu objek [KelopakBackend].
library;

import '../domain/campaign.dart';
import '../domain/checkout.dart';
import '../domain/outcomes.dart';
import '../domain/state.dart';

/// Balasan sebuah aksi: [value] hasilnya dan [state] keadaan sesudahnya
/// (selalu keadaan terbaru yang sah, juga bila aksi ditolak).
final class KelopakReply<T> {
  const KelopakReply({required this.state, required this.value});

  /// Keadaan Kelopak setelah aksi.
  final KelopakState state;

  /// Hasil aksi.
  final T value;
}

/// Aksi gagal diproses backend (jaringan putus, balasan server tidak sah).
/// Aturan bisnis yang menolak aksi bukan galat: itu datang sebagai hasil.
final class KelopakBackendException implements Exception {
  const KelopakBackendException(this.message, {this.cause});

  /// Pesan untuk pengguna.
  final String message;

  /// Galat asal, bila ada.
  final Object? cause;

  @override
  String toString() => 'KelopakBackendException: $message';
}

/// Sumber dan pencatat data Kelopak seorang pengguna.
///
/// Semua aksi asinkron dan mengembalikan [KelopakReply]. [today] adalah hari
/// WIB menurut aplikasi (termasuk geseran Mode Demo); server produksi memakai
/// jamnya sendiri dan boleh mengabaikannya.
abstract interface class KelopakBackend {
  /// Kampanye yang dipakai backend ini.
  KelopakCampaign get campaign;

  /// Memuat keadaan saat aplikasi dibuka.
  Future<KelopakState> load();

  /// Keadaan terbaru bila berubah di luar instans ini (tab lain, perangkat
  /// lain); null bila tidak ada yang baru.
  Future<KelopakState?> refresh();

  /// Klaim Check-in Harian.
  Future<KelopakReply<CheckInOutcome>> claimCheckIn({required int today});

  /// Memutar Roda Sabtu; backend yang mengundi.
  Future<KelopakReply<SpinOutcome>> spin({required int today});

  /// Klaim voucher promo [promoId] (sekali per pengguna).
  Future<KelopakReply<PromoClaimOutcome>> claimPromoVoucher({
    required String promoId,
    required int amount,
    required int minSpend,
    required int validDays,
    required String title,
    required int today,
  });

  /// Mengikat [quote] ke pesanan [orderId].
  Future<KelopakReply<CommitOutcome>> commitOrder({
    required String orderId,
    required CheckoutQuote quote,
    required int today,
  });

  /// Membatalkan pesanan; null bila tidak bisa dibatalkan.
  Future<KelopakReply<OrderCancellation?>> cancelOrder({
    required String orderId,
    required int today,
  });

  /// Menandai pesanan dikirim; null bila tidak ada pesanan yang cocok.
  Future<KelopakReply<KelopakOrder?>> shipOrder({required String orderId});

  /// "Pesanan Diterima"; null bila tidak ada pesanan yang masih berjalan.
  Future<KelopakReply<OrderCompletion?>> completeOrder({
    required String orderId,
    required int today,
  });

  /// Alat Mode Demo; null pada backend yang tidak menyediakannya (server
  /// produksi).
  KelopakDemoTools? get demoTools;

  /// Selesai saat semua penulisan tertunda sudah tersimpan.
  Future<void> flush();
}

/// Alat Mode Demo (QA): hanya ada di backend lokal.
abstract interface class KelopakDemoTools {
  /// Menyalakan atau mematikan promo Roda Sabtu.
  Future<KelopakState> setPromoActive(bool active);

  /// Mengatur sisa kuota hadiah produk roda.
  Future<KelopakState> setWheelQuotaLeft(int left, {required int today});

  /// Menambah saldo Kelopak.
  Future<KelopakState> grantKelopak(int amount, {required int today});

  /// Menghapus seluruh data hadiah.
  Future<KelopakState> reset();
}
