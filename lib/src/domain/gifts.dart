/// Hadiah menunggu: produk gratis yang ikut pesanan belanja berikutnya
/// (KEPUTUSAN §2, K17). Dart murni.
library;

import '../storage/json_reader.dart';

/// Asal hadiah produk gratis.
enum GiftSource {
  /// Hadiah produk Roda Sabtu.
  wheel('Roda Sabtu'),

  /// Hari ke-30, 60, ... Check-in Harian tanpa putus.
  checkIn30('Check-in 30 hari beruntun');

  const GiftSource(this.label);

  /// Label untuk keranjang dan "Hadiahku".
  final String label;
}

/// Perjalanan sebuah hadiah: menunggu, terlampir ke pesanan, dikirim,
/// diterima. Pesanan batal mengembalikannya ke [pending].
enum GiftStatus {
  /// Menunggu pesanan belanja berikutnya.
  pending('Menunggu pesanan berikutnya'),

  /// Terlampir ke sebuah pesanan yang belum dikirim.
  attached('Ikut pesananmu'),

  /// Dikirim bersama pesanannya.
  shipped('Dikirim'),

  /// Sudah diterima.
  received('Diterima');

  const GiftStatus(this.label);

  /// Teks status.
  final String label;
}

/// Satu produk gratis milik pengguna.
final class PendingGift {
  const PendingGift({
    required this.id,
    required this.source,
    required this.wonDay,
    this.productCode,
    this.status = GiftStatus.pending,
    this.orderId,
  });

  /// Memulihkan hadiah hasil [toJson]; melempar [FormatException] bila rusak.
  factory PendingGift.fromJson(Object? source) {
    final json = asJsonMap(source, 'gift');
    final gift = PendingGift(
      id: readString(json, 'id'),
      source: readEnum(json, 'source', GiftSource.values),
      wonDay: readInt(json, 'wonDay'),
      productCode: readOptionalString(json, 'productCode'),
      status: readEnum(
        json,
        'status',
        GiftStatus.values,
        fallback: GiftStatus.pending,
      ),
      orderId: readOptionalString(json, 'orderId'),
    );
    if ((gift.status == GiftStatus.pending) != (gift.orderId == null)) {
      throw const FormatException('Gift status and order do not match');
    }
    return gift;
  }

  /// ID unik, misalnya `HG-0001`.
  final String id;

  /// Asal hadiah.
  final GiftSource source;

  /// Hari WIB saat hadiah dimenangkan.
  final int wonDay;

  /// Kode produk katalog; null bila kampanye belum menentukan produknya.
  final String? productCode;

  /// Status pengiriman.
  final GiftStatus status;

  /// Pesanan yang membawa hadiah ini; null selama [GiftStatus.pending].
  final String? orderId;

  /// Apakah hadiah masih menunggu pesanan.
  bool get isPending => status == GiftStatus.pending;

  /// Salinan berstatus [status] untuk pesanan [orderId].
  PendingGift withStatus(GiftStatus status, {String? orderId}) => PendingGift(
    id: id,
    source: source,
    wonDay: wonDay,
    productCode: productCode,
    status: status,
    orderId: status == GiftStatus.pending ? null : orderId ?? this.orderId,
  );

  /// Menyerialkan hadiah.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source.name,
    'wonDay': wonDay,
    'productCode': productCode,
    'status': status.name,
    'orderId': orderId,
  };

  @override
  bool operator ==(Object other) =>
      other is PendingGift &&
      other.id == id &&
      other.source == source &&
      other.wonDay == wonDay &&
      other.productCode == productCode &&
      other.status == status &&
      other.orderId == orderId;

  @override
  int get hashCode =>
      Object.hash(id, source, wonDay, productCode, status, orderId);

  @override
  String toString() =>
      'PendingGift($id, ${source.name}, $productCode, ${status.name}, $orderId)';
}
