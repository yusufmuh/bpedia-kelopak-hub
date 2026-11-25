/// Kutipan checkout dan catatan pesanan milik sistem Kelopak (Dart murni).
///
/// Urutan hitung (KEPUTUSAN §1): subtotal barang, kurangi voucher, lalu
/// Kelopak memotong sisa harga barang; ongkir ditambahkan terakhir dan tidak
/// pernah dipotong Kelopak. Hadiah menunggu ikut sebagai baris Rp0 bila ada
/// minimal satu barang berbayar (KEPUTUSAN §2).
library;

import 'package:misi_belanja/misi_belanja.dart'
    show MissionOrderLine, RedeemProblem;

import '../storage/json_reader.dart';
import 'campaign.dart';
import 'gifts.dart';
import 'voucher.dart';

/// Satu baris barang berbayar: [quantity] buah [productCode] seharga
/// [unitPrice] rupiah per buah (setelah diskon produk).
final class CheckoutLine {
  const CheckoutLine({
    required this.productCode,
    required this.unitPrice,
    required this.quantity,
  });

  /// Memulihkan baris hasil [toJson]; melempar [FormatException] bila rusak.
  factory CheckoutLine.fromJson(Object? source) {
    final json = asJsonMap(source, 'checkout line');
    final line = CheckoutLine(
      productCode: readString(json, 'productCode'),
      unitPrice: readInt(json, 'unitPrice'),
      quantity: readInt(json, 'quantity'),
    );
    if (line.productCode.isEmpty || line.unitPrice < 0 || line.quantity < 1) {
      throw const FormatException('Invalid checkout line');
    }
    return line;
  }

  /// Kode produk katalog.
  final String productCode;

  /// Harga satuan dalam rupiah.
  final int unitPrice;

  /// Jumlah barang.
  final int quantity;

  /// Harga x jumlah; 0 untuk harga atau jumlah yang tidak positif.
  int get lineTotal => unitPrice > 0 && quantity > 0 ? unitPrice * quantity : 0;

  /// Baris yang sama untuk aturan `misi_belanja`.
  MissionOrderLine get asMissionLine => MissionOrderLine(
    productCode: productCode,
    unitPrice: unitPrice < 0 ? 0 : unitPrice,
    quantity: quantity < 0 ? 0 : quantity,
  );

  /// Menyerialkan baris.
  Map<String, Object?> toJson() => <String, Object?>{
    'productCode': productCode,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  @override
  bool operator ==(Object other) =>
      other is CheckoutLine &&
      other.productCode == productCode &&
      other.unitPrice == unitPrice &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(productCode, unitPrice, quantity);

  @override
  String toString() => 'CheckoutLine($productCode, $unitPrice x $quantity)';
}

/// Jumlah [CheckoutLine.lineTotal] seluruh [lines].
int goodsSubtotalOf(Iterable<CheckoutLine> lines) {
  var total = 0;
  for (final line in lines) {
    total += line.lineTotal;
  }
  return total;
}

/// Yang diminta pengguna di layar checkout.
final class CheckoutRequest {
  CheckoutRequest({
    required List<CheckoutLine> lines,
    this.shippingFee = 0,
    this.voucherId,
    this.useKelopak = true,
  }) : lines = List<CheckoutLine>.unmodifiable(lines) {
    if (shippingFee < 0) {
      throw ArgumentError.value(
        shippingFee,
        'shippingFee',
        'must not be negative',
      );
    }
  }

  /// Memulihkan permintaan hasil [toJson].
  factory CheckoutRequest.fromJson(Object? source) {
    final json = asJsonMap(source, 'checkout request');
    final fee = readInt(json, 'shippingFee', fallback: 0);
    if (fee < 0) throw const FormatException('Negative shipping fee');
    return CheckoutRequest(
      lines: readList(json, 'lines', CheckoutLine.fromJson),
      shippingFee: fee,
      voucherId: readOptionalString(json, 'voucherId'),
      useKelopak: readBool(json, 'useKelopak', fallback: true),
    );
  }

  /// Barang berbayar yang dipilih.
  final List<CheckoutLine> lines;

  /// Ongkos kirim dalam rupiah.
  final int shippingFee;

  /// Voucher yang dipilih, atau null.
  final String? voucherId;

  /// Sakelar "Pakai Kelopak" (menyala secara bawaan).
  final bool useKelopak;

  /// Menyerialkan permintaan.
  Map<String, Object?> toJson() => <String, Object?>{
    'lines': lines.map((line) => line.toJson()).toList(),
    'shippingFee': shippingFee,
    'voucherId': voucherId,
    'useKelopak': useKelopak,
  };
}

/// Rincian harga sebuah [CheckoutRequest] pada satu hari WIB.
///
/// Hitung ulang setiap kali keranjang, voucher, atau sakelar Kelopak berubah;
/// komit hanya menerima kutipan yang [token]-nya masih cocok dengan keadaan
/// saat itu.
final class CheckoutQuote {
  CheckoutQuote({
    required this.day,
    required this.request,
    required this.goodsSubtotal,
    required this.voucherId,
    required this.voucherAmount,
    required this.voucherProblem,
    required this.kelopakBalance,
    required this.kelopakMax,
    required this.kelopakUsed,
    required this.kelopakValue,
    required List<PendingGift> gifts,
    required this.waitingGiftCount,
    required this.total,
  }) : gifts = List<PendingGift>.unmodifiable(gifts);

  /// Hari WIB kutipan dibuat.
  final int day;

  /// Permintaan yang dikutip.
  final CheckoutRequest request;

  /// Subtotal barang berbayar; dasar syarat minimum voucher dan misi.
  final int goodsSubtotal;

  /// Voucher yang diminta (null bila tidak ada atau ID tidak dikenal).
  final String? voucherId;

  /// Potongan voucher dalam rupiah (0 bila voucher bermasalah).
  final int voucherAmount;

  /// Mengapa voucher yang diminta tidak bisa dipakai, atau null.
  final RedeemProblem? voucherProblem;

  /// Saldo Kelopak saat kutipan dibuat.
  final int kelopakBalance;

  /// Kelopak terbanyak yang bisa dipakai di pesanan ini.
  final int kelopakMax;

  /// Kelopak yang dipakai (0 bila sakelar mati).
  final int kelopakUsed;

  /// Nilai rupiah [kelopakUsed].
  final int kelopakValue;

  /// Hadiah menunggu yang ikut pesanan ini (baris Rp0). Kosong bila tidak
  /// ada barang berbayar.
  final List<PendingGift> gifts;

  /// Jumlah hadiah menunggu milik pengguna, ikut atau tidak.
  final int waitingGiftCount;

  /// Yang harus dibayar: sisa harga barang + ongkir.
  final int total;

  /// Ongkos kirim.
  int get shippingFee => request.shippingFee;

  /// Apakah sakelar "Pakai Kelopak" menyala.
  bool get useKelopak => request.useKelopak;

  /// Apakah voucher yang diminta terpakai.
  bool get voucherApplied => voucherId != null && voucherProblem == null;

  /// Harga barang setelah voucher, sebelum Kelopak.
  int get goodsAfterVoucher => goodsSubtotal - voucherAmount;

  /// Apakah ada minimal satu barang berbayar.
  bool get hasPaidItems => goodsSubtotal > 0;

  /// Apakah ada hadiah yang tertahan karena belum ada barang berbayar
  /// ("Tambah minimal 1 produk supaya hadiahmu bisa dikirim").
  bool get giftsBlocked => !hasPaidItems && waitingGiftCount > 0;

  /// Total Rp0: tidak perlu metode bayar ("Lunas dengan Kelopak").
  bool get isFullyCovered => hasPaidItems && total == 0;

  /// Sidik kutipan: berubah bila ada angka, barang, voucher, atau hadiah yang
  /// berubah. Dipakai komit untuk menolak kutipan basi.
  String get token {
    final lines = request.lines
        .map((l) => '${l.productCode}*${l.unitPrice}*${l.quantity}')
        .join(',');
    final giftIds = gifts.map((gift) => gift.id).join(',');
    return 'kq1|$day|$lines|$shippingFee|'
        '${voucherApplied ? voucherId : '-'}|$voucherAmount|'
        '$kelopakUsed|$giftIds|$total';
  }

  @override
  bool operator ==(Object other) =>
      other is CheckoutQuote &&
      other.token == token &&
      other.voucherId == voucherId &&
      other.voucherProblem == voucherProblem &&
      other.useKelopak == useKelopak &&
      other.kelopakMax == kelopakMax;

  @override
  int get hashCode => Object.hash(token, voucherId, voucherProblem, kelopakMax);

  @override
  String toString() => 'CheckoutQuote($token)';
}

/// Menghitung kutipan (fungsi murni).
///
/// * [voucher]: voucher yang diminta, sudah dicari dari
///   [CheckoutRequest.voucherId]; null bila tidak ada atau tidak dikenal.
/// * [balance]: saldo Kelopak pengguna.
/// * [pendingGifts]: hadiah berstatus menunggu.
/// * [orderId]: nomor pesanan bila sudah diketahui (saat komit); voucher misi
///   tidak bisa dipakai di pesanan yang menerbitkannya.
CheckoutQuote computeCheckoutQuote({
  required KelopakPolicy policy,
  required CheckoutRequest request,
  required int balance,
  required KelopakVoucher? voucher,
  required List<PendingGift> pendingGifts,
  required int today,
  String orderId = '',
}) {
  final goodsSubtotal = goodsSubtotalOf(request.lines);
  RedeemProblem? voucherProblem;
  var voucherAmount = 0;
  if (voucher != null) {
    voucherProblem = voucher.problemFor(
      orderId: orderId,
      subtotal: goodsSubtotal,
      today: today,
    );
    if (voucherProblem == null) {
      voucherAmount = voucher.amount < goodsSubtotal
          ? voucher.amount
          : goodsSubtotal;
    }
  }
  final goodsAfterVoucher = goodsSubtotal - voucherAmount;
  final cap = policy.maxKelopakFor(goodsAfterVoucher);
  final safeBalance = balance < 0 ? 0 : balance;
  final kelopakMax = cap < safeBalance ? cap : safeBalance;
  final kelopakUsed = request.useKelopak ? kelopakMax : 0;
  final kelopakValue = policy.rupiahOf(kelopakUsed);
  final waiting = pendingGifts.where((gift) => gift.isPending).toList();
  return CheckoutQuote(
    day: today,
    request: request,
    goodsSubtotal: goodsSubtotal,
    voucherId: voucher?.id,
    voucherAmount: voucherAmount,
    voucherProblem: voucherProblem,
    kelopakBalance: safeBalance,
    kelopakMax: kelopakMax,
    kelopakUsed: kelopakUsed,
    kelopakValue: kelopakValue,
    gifts: goodsSubtotal > 0 ? waiting : const <PendingGift>[],
    waitingGiftCount: waiting.length,
    total: goodsAfterVoucher - kelopakValue + request.shippingFee,
  );
}

/// Mengapa sebuah kutipan tidak bisa dikomit.
enum CheckoutProblem {
  /// Tidak ada barang berbayar (hadiah gratis tidak bisa dikirim sendirian).
  noPaidItems('Tambah minimal 1 produk dulu, Babes.'),

  /// Keranjang, voucher, saldo, hadiah, atau tanggal berubah sejak kutipan.
  quoteOutdated('Rincian pesananmu berubah. Cek lagi sebelum bayar, ya.'),

  /// Nomor pesanan sudah dipakai pesanan lain.
  duplicateOrder('Pesanan ini sudah tercatat.');

  const CheckoutProblem(this.message);

  /// Pesan untuk pengguna.
  final String message;
}

/// Status pesanan di sisi sistem Kelopak.
enum KelopakOrderStatus {
  /// Dibuat (menunggu pembayaran atau dikemas); masih bisa dibatalkan.
  placed,

  /// Dikirim; hadiah terlampir ikut dikirim.
  shipped,

  /// Diterima; misi sudah dievaluasi.
  completed,

  /// Dibatalkan; Kelopak, voucher, dan hadiah sudah dikembalikan.
  cancelled,
}

/// Yang disimpan sistem Kelopak tentang sebuah pesanan saat komit, supaya
/// batal, kirim, dan selesai bisa diproses tanpa bertanya lagi ke app.
final class KelopakOrder {
  KelopakOrder({
    required this.id,
    required this.placedDay,
    required List<CheckoutLine> lines,
    required this.goodsSubtotal,
    required this.shippingFee,
    required this.voucherAmount,
    required this.kelopakUsed,
    required this.kelopakValue,
    required List<String> giftIds,
    required this.total,
    required this.quoteToken,
    this.voucherId,
    this.status = KelopakOrderStatus.placed,
    this.closedDay,
  }) : lines = List<CheckoutLine>.unmodifiable(lines),
       giftIds = List<String>.unmodifiable(giftIds);

  /// Memulihkan pesanan hasil [toJson]; melempar [FormatException] bila rusak.
  factory KelopakOrder.fromJson(Object? source) {
    final json = asJsonMap(source, 'order');
    final order = KelopakOrder(
      id: readString(json, 'id'),
      placedDay: readInt(json, 'placedDay'),
      lines: readList(json, 'lines', CheckoutLine.fromJson),
      goodsSubtotal: readInt(json, 'goodsSubtotal'),
      shippingFee: readInt(json, 'shippingFee', fallback: 0),
      voucherId: readOptionalString(json, 'voucherId'),
      voucherAmount: readInt(json, 'voucherAmount', fallback: 0),
      kelopakUsed: readInt(json, 'kelopakUsed', fallback: 0),
      kelopakValue: readInt(json, 'kelopakValue', fallback: 0),
      giftIds: readStringList(json, 'giftIds'),
      total: readInt(json, 'total'),
      quoteToken: readString(json, 'quoteToken', fallback: ''),
      status: readEnum(json, 'status', KelopakOrderStatus.values),
      closedDay: readOptionalInt(json, 'closedDay'),
    );
    final amounts = <int>[
      order.goodsSubtotal,
      order.shippingFee,
      order.voucherAmount,
      order.kelopakUsed,
      order.kelopakValue,
      order.total,
    ];
    if (order.id.isEmpty ||
        order.lines.isEmpty ||
        amounts.any((value) => value < 0)) {
      throw const FormatException('Invalid order');
    }
    return order;
  }

  /// Nomor pesanan dari app (misalnya `BP-261124-0001`).
  final String id;

  /// Hari WIB pesanan dibuat.
  final int placedDay;

  /// Barang berbayar saat pesanan dibuat; dasar evaluasi misi.
  final List<CheckoutLine> lines;

  /// Subtotal barang berbayar.
  final int goodsSubtotal;

  /// Ongkos kirim.
  final int shippingFee;

  /// Voucher yang dipakai, atau null.
  final String? voucherId;

  /// Potongan voucher dalam rupiah.
  final int voucherAmount;

  /// Kelopak yang dipakai.
  final int kelopakUsed;

  /// Nilai rupiah [kelopakUsed].
  final int kelopakValue;

  /// Hadiah yang ikut pesanan ini.
  final List<String> giftIds;

  /// Yang dibayar.
  final int total;

  /// Sidik kutipan yang dikomit (untuk komit ulang yang idempoten).
  final String quoteToken;

  /// Status saat ini.
  final KelopakOrderStatus status;

  /// Hari WIB pesanan selesai atau dibatalkan.
  final int? closedDay;

  /// Apakah pesanan masih berjalan (belum selesai dan belum batal).
  bool get isOpen =>
      status == KelopakOrderStatus.placed ||
      status == KelopakOrderStatus.shipped;

  /// Salinan berstatus [status].
  KelopakOrder withStatus(KelopakOrderStatus status, {int? closedDay}) =>
      KelopakOrder(
        id: id,
        placedDay: placedDay,
        lines: lines,
        goodsSubtotal: goodsSubtotal,
        shippingFee: shippingFee,
        voucherId: voucherId,
        voucherAmount: voucherAmount,
        kelopakUsed: kelopakUsed,
        kelopakValue: kelopakValue,
        giftIds: giftIds,
        total: total,
        quoteToken: quoteToken,
        status: status,
        closedDay: closedDay ?? this.closedDay,
      );

  /// Menyerialkan pesanan.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'placedDay': placedDay,
    'lines': lines.map((line) => line.toJson()).toList(),
    'goodsSubtotal': goodsSubtotal,
    'shippingFee': shippingFee,
    'voucherId': voucherId,
    'voucherAmount': voucherAmount,
    'kelopakUsed': kelopakUsed,
    'kelopakValue': kelopakValue,
    'giftIds': giftIds,
    'total': total,
    'quoteToken': quoteToken,
    'status': status.name,
    'closedDay': closedDay,
  };

  @override
  String toString() => 'KelopakOrder($id, ${status.name}, total $total)';
}
