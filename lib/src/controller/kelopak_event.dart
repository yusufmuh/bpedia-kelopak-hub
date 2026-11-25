/// Peristiwa yang dipancarkan sistem Kelopak. Hub tidak mengenal analitik
/// maupun notifikasi: aplikasi induk memetakan [KelopakEvent] ke keduanya.
library;

import '../core/format.dart';
import '../core/paths.dart';
import '../domain/gifts.dart';
import '../domain/voucher.dart';

/// Isi kotak masuk yang disarankan untuk sebuah peristiwa.
final class KelopakNotice {
  const KelopakNotice({
    required this.title,
    required this.body,
    required this.route,
  });

  /// Judul notifikasi.
  final String title;

  /// Isi notifikasi.
  final String body;

  /// Rute yang dibuka saat notifikasi diketuk.
  final String route;
}

/// Dasar semua peristiwa.
///
/// [analyticsName] berisi nama event KEPUTUSAN §7 (`bp_*`) atau null bila
/// peristiwa itu bukan event analitik. [parameters] hanya berisi angka, teks,
/// dan boolean. [notice] berisi saran isi kotak masuk, atau null.
sealed class KelopakEvent {
  const KelopakEvent();

  /// Nama event analitik, atau null.
  String? get analyticsName => null;

  /// Parameter event (aman untuk analitik: tanpa data pribadi).
  Map<String, Object> get parameters => const <String, Object>{};

  /// Saran notifikasi kotak masuk, atau null.
  KelopakNotice? get notice => null;
}

/// Check-in Harian diklaim.
final class CheckInClaimedEvent extends KelopakEvent {
  const CheckInClaimedEvent({
    required this.streak,
    required this.kelopak,
    this.gift,
  });

  /// Rentetan setelah klaim.
  final int streak;

  /// Kelopak yang didapat (harian + bonus).
  final int kelopak;

  /// Hadiah produk hari ke-30, bila ada.
  final PendingGift? gift;

  @override
  String get analyticsName => 'bp_checkin_claim';

  @override
  Map<String, Object> get parameters => <String, Object>{
    'streak': streak,
    'kelopak': kelopak,
    'product_gift': gift != null,
  };

  @override
  KelopakNotice? get notice => gift == null
      ? null
      : const KelopakNotice(
          title: 'Produk gratis dari Check-in 30 hari',
          body:
              'Selamat, Babes! Hadiahmu masuk ke keranjang dan dikirim '
              'bersama pesanan berikutnya.',
          route: KelopakPaths.myGifts,
        );
}

/// Roda Sabtu diputar.
final class WheelSpunEvent extends KelopakEvent {
  const WheelSpunEvent({
    required this.prizeId,
    required this.kelopak,
    this.gift,
  });

  /// ID hadiah yang dimenangkan.
  final String prizeId;

  /// Kelopak yang didapat (0 untuk hadiah produk).
  final int kelopak;

  /// Hadiah produk, bila menang produk.
  final PendingGift? gift;

  @override
  String get analyticsName => 'bp_wheel_spin';

  @override
  Map<String, Object> get parameters => <String, Object>{
    'prize_id': prizeId,
    'kelopak': kelopak,
    'product_gift': gift != null,
    if (gift?.productCode != null) 'product_code': gift!.productCode!,
  };

  @override
  KelopakNotice? get notice => gift == null
      ? null
      : const KelopakNotice(
          title: 'Kamu menang produk gratis',
          body:
              'Hadiah Roda Sabtu masuk ke keranjang dan dikirim bersama '
              'pesanan berikutnya, tanpa ongkir tambahan.',
          route: KelopakPaths.myGifts,
        );
}

/// Sebuah tahap Misi Belanja selesai dan vouchernya terbit.
final class MissionCompletedEvent extends KelopakEvent {
  const MissionCompletedEvent({
    required this.orderId,
    required this.stageNumber,
    required this.voucher,
  });

  /// Pesanan yang menyelesaikan tahap.
  final String orderId;

  /// Nomor tahap.
  final int stageNumber;

  /// Voucher yang terbit.
  final KelopakVoucher voucher;

  @override
  String get analyticsName => 'bp_mission_complete';

  @override
  Map<String, Object> get parameters => <String, Object>{
    'stage': stageNumber,
    'order_id': orderId,
    'voucher_id': voucher.id,
    'voucher_amount': voucher.amount,
  };

  @override
  KelopakNotice get notice => KelopakNotice(
    title: 'Misi Belanja tahap $stageNumber tuntas',
    body:
        'Voucher ${rupiah(voucher.amount)} siap dipakai untuk belanja min. '
        '${rupiah(voucher.minSpend)}.',
    route: KelopakPaths.vouchers,
  );
}

/// Voucher dipakai di sebuah pesanan.
final class VoucherRedeemedEvent extends KelopakEvent {
  const VoucherRedeemedEvent({
    required this.orderId,
    required this.voucherId,
    required this.amount,
  });

  /// Pesanan pemakai.
  final String orderId;

  /// Voucher yang dipakai.
  final String voucherId;

  /// Potongan dalam rupiah.
  final int amount;

  @override
  String get analyticsName => 'bp_voucher_redeem';

  @override
  Map<String, Object> get parameters => <String, Object>{
    'order_id': orderId,
    'voucher_id': voucherId,
    'amount': amount,
  };
}

/// Kelopak dipakai sebagai potongan di sebuah pesanan.
final class KelopakRedeemedEvent extends KelopakEvent {
  const KelopakRedeemedEvent({
    required this.orderId,
    required this.kelopak,
    required this.value,
  });

  /// Pesanan pemakai.
  final String orderId;

  /// Kelopak yang dipakai.
  final int kelopak;

  /// Nilai rupiahnya.
  final int value;

  @override
  String get analyticsName => 'bp_kelopak_redeem';

  @override
  Map<String, Object> get parameters => <String, Object>{
    'order_id': orderId,
    'kelopak': kelopak,
    'value': value,
  };
}

/// Hadiah menunggu terlampir ke sebuah pesanan.
final class GiftAttachedEvent extends KelopakEvent {
  GiftAttachedEvent({required this.orderId, required List<PendingGift> gifts})
    : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Pesanan pembawa hadiah.
  final String orderId;

  /// Hadiah yang terlampir.
  final List<PendingGift> gifts;

  @override
  String get analyticsName => 'bp_gift_attached';

  @override
  Map<String, Object> get parameters => <String, Object>{
    'order_id': orderId,
    'gift_count': gifts.length,
  };
}

/// Pesanan dibatalkan: Kelopak, voucher, dan hadiah dikembalikan.
final class OrderRefundedEvent extends KelopakEvent {
  OrderRefundedEvent({
    required this.orderId,
    required this.kelopak,
    required List<PendingGift> gifts,
    this.voucher,
  }) : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Pesanan yang dibatalkan.
  final String orderId;

  /// Kelopak yang kembali ke saldo.
  final int kelopak;

  /// Voucher yang kembali bisa dipakai.
  final KelopakVoucher? voucher;

  /// Hadiah yang kembali menunggu.
  final List<PendingGift> gifts;

  /// Apakah ada yang dikembalikan.
  bool get hasRefund => kelopak > 0 || voucher != null || gifts.isNotEmpty;

  @override
  Map<String, Object> get parameters => <String, Object>{
    'order_id': orderId,
    'kelopak': kelopak,
    'voucher_released': voucher != null,
    'gift_count': gifts.length,
  };

  @override
  KelopakNotice? get notice {
    if (!hasRefund) return null;
    final parts = <String>[
      if (kelopak > 0) kelopakLabel(kelopak),
      if (voucher != null) 'voucher ${rupiah(voucher!.amount)}',
      if (gifts.isNotEmpty) '${gifts.length} hadiah gratis',
    ];
    return KelopakNotice(
      title: 'Hadiahmu dikembalikan',
      body: 'Dari pesanan $orderId yang dibatalkan: ${parts.join(', ')}.',
      route: KelopakPaths.rewards,
    );
  }
}

/// Hadiah gratis ikut dikirim bersama pesanannya.
final class GiftsShippedEvent extends KelopakEvent {
  GiftsShippedEvent({required this.orderId, required List<PendingGift> gifts})
    : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Pesanan pembawa hadiah.
  final String orderId;

  /// Hadiah yang dikirim.
  final List<PendingGift> gifts;

  @override
  Map<String, Object> get parameters => <String, Object>{
    'order_id': orderId,
    'gift_count': gifts.length,
  };
}

/// Hadiah gratis diterima bersama pesanannya.
final class GiftsReceivedEvent extends KelopakEvent {
  GiftsReceivedEvent({required this.orderId, required List<PendingGift> gifts})
    : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Pesanan pembawa hadiah.
  final String orderId;

  /// Hadiah yang diterima.
  final List<PendingGift> gifts;

  @override
  Map<String, Object> get parameters => <String, Object>{
    'order_id': orderId,
    'gift_count': gifts.length,
  };
}

/// Voucher promo diklaim.
final class PromoVoucherClaimedEvent extends KelopakEvent {
  const PromoVoucherClaimedEvent(this.voucher);

  /// Voucher baru.
  final KelopakVoucher voucher;

  @override
  Map<String, Object> get parameters => <String, Object>{
    'promo_id': voucher.promoId ?? '',
    'voucher_id': voucher.id,
    'amount': voucher.amount,
  };

  @override
  KelopakNotice get notice => KelopakNotice(
    title: 'Voucher ${rupiah(voucher.amount)} masuk ke dompetmu',
    body:
        'Pakai untuk belanja min. ${rupiah(voucher.minSpend)} sebelum '
        '${wibDateLabel(voucher.expiresDay)}.',
    route: KelopakPaths.vouchers,
  );
}
