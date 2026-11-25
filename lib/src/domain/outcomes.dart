/// Hasil tiap aksi mesin Kelopak (Dart murni). Keadaan yang wajar terjadi
/// (sudah klaim, bukan Sabtu, kutipan basi) dikembalikan sebagai hasil, bukan
/// dilempar sebagai galat.
library;

import 'package:daily_checkin/daily_checkin.dart' show CheckInAward;
import 'package:misi_belanja/misi_belanja.dart' show MissionDecision;
import 'package:roda_sabtu/roda_sabtu.dart'
    show SpinEligibility, SpinOdds, SpinPrize;

import 'checkout.dart';
import 'gifts.dart';
import 'state.dart';
import 'voucher.dart';

/// Hasil klaim Check-in Harian.
sealed class CheckInOutcome {
  const CheckInOutcome();
}

/// Check-in dibukukan: [award] dari modul, saldo sesudahnya, dan hadiah
/// produk hari ke-30, 60, ...
final class CheckInClaimed extends CheckInOutcome {
  const CheckInClaimed({
    required this.award,
    required this.newBalance,
    this.gift,
  });

  /// Hasil aturan modul (rentetan, harian, bonus, hak produk).
  final CheckInAward award;

  /// Saldo Kelopak setelah klaim.
  final int newBalance;

  /// Hadiah menunggu yang dibuat klaim ini, bila ada.
  final PendingGift? gift;
}

/// Hari ini sudah diklaim; tidak ada yang berubah.
final class CheckInAlreadyClaimed extends CheckInOutcome {
  const CheckInAlreadyClaimed();
}

/// Hasil memutar Roda Sabtu.
sealed class SpinOutcome {
  const SpinOutcome();
}

/// Putaran dibukukan. Hadiah Kelopak sudah dikreditkan; hadiah produk membuat
/// [gift] dan memakai satu kuota.
final class SpinCompleted extends SpinOutcome {
  const SpinCompleted({
    required this.record,
    required this.prize,
    required this.odds,
    required this.newBalance,
    this.gift,
  });

  /// Catatan tersimpan (berikan `prizeId` dan `landingSeed` ke roda).
  final SpinRecord record;

  /// Hadiah yang dimenangkan.
  final SpinPrize prize;

  /// Peluang saat putaran diputuskan. Tampilkan ini di roda sampai berhenti:
  /// peluang sekarang bisa sudah berbeda (kuota terakhir baru saja keluar).
  final List<SpinOdds> odds;

  /// Saldo Kelopak setelah putaran.
  final int newBalance;

  /// Hadiah menunggu untuk hadiah produk.
  final PendingGift? gift;
}

/// Belum boleh memutar; [eligibility] menyebut alasannya.
final class SpinRejected extends SpinOutcome {
  const SpinRejected(this.eligibility);

  /// Alasan penolakan (tidak pernah `SpinEligibility.available`).
  final SpinEligibility eligibility;
}

/// Hasil komit pesanan.
sealed class CommitOutcome {
  const CommitOutcome();
}

/// Pesanan tercatat: Kelopak didebit, voucher ditandai, hadiah terlampir.
final class OrderCommitted extends CommitOutcome {
  const OrderCommitted(this.order);

  /// Catatan pesanan.
  final KelopakOrder order;
}

/// Tidak ada yang berubah; kutip ulang dan tampilkan angka baru.
final class OrderNotCommitted extends CommitOutcome {
  const OrderNotCommitted(this.problem);

  /// Mengapa pesanan tidak dikomit.
  final CheckoutProblem problem;
}

/// Hasil membatalkan pesanan: apa saja yang dikembalikan.
final class OrderCancellation {
  OrderCancellation({
    required this.order,
    required this.kelopakRefunded,
    required List<PendingGift> gifts,
    this.voucher,
  }) : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Pesanan, kini `cancelled`.
  final KelopakOrder order;

  /// Kelopak yang dikembalikan ke saldo.
  final int kelopakRefunded;

  /// Voucher yang kembali bisa dipakai, bila pesanan memakainya.
  final KelopakVoucher? voucher;

  /// Hadiah yang kembali menunggu.
  final List<PendingGift> gifts;
}

/// Hasil "Pesanan Diterima".
final class OrderCompletion {
  OrderCompletion({
    required this.order,
    required this.decision,
    required List<PendingGift> gifts,
    this.voucher,
  }) : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Pesanan, kini `completed`.
  final KelopakOrder order;

  /// Keputusan Misi Belanja untuk pesanan ini.
  final MissionDecision decision;

  /// Voucher yang terbit dari pesanan ini, bila ada.
  final KelopakVoucher? voucher;

  /// Hadiah gratis yang ikut diterima.
  final List<PendingGift> gifts;
}

/// Mengapa voucher promo tidak bisa diklaim.
enum PromoClaimProblem {
  /// Promo ini sudah pernah diklaim pengguna.
  alreadyClaimed('Voucher ini sudah kamu klaim, Babes.'),

  /// Nilai, minimum belanja, atau masa berlaku tidak sah.
  invalidTerms('Voucher belum bisa diklaim.');

  const PromoClaimProblem(this.message);

  /// Pesan untuk pengguna.
  final String message;
}

/// Hasil klaim voucher promo.
sealed class PromoClaimOutcome {
  const PromoClaimOutcome();
}

/// Voucher promo masuk ke dompet.
final class PromoVoucherClaimed extends PromoClaimOutcome {
  const PromoVoucherClaimed(this.voucher);

  /// Voucher baru.
  final KelopakVoucher voucher;
}

/// Klaim ditolak; tidak ada yang berubah.
final class PromoVoucherNotClaimed extends PromoClaimOutcome {
  const PromoVoucherNotClaimed(this.problem);

  /// Alasan penolakan.
  final PromoClaimProblem problem;
}
