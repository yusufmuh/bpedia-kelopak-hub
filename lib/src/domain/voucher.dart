/// Voucher belanja milik pengguna: hasil Misi Belanja atau klaim promo.
/// Aturan pakainya tetap `redeemProblem` modul `misi_belanja`. Dart murni.
library;

import 'package:misi_belanja/misi_belanja.dart'
    show MissionStage, MissionVoucher, RedeemProblem, redeemProblem;

import '../storage/json_reader.dart';

/// Asal voucher.
enum VoucherKind {
  /// Diterbitkan saat sebuah tahap Misi Belanja selesai.
  mission,

  /// Diklaim dari halaman Event Promo.
  promo,
}

/// Satu voucher potongan harga barang. Hari adalah hari WIB; voucher berlaku
/// sampai dan termasuk [expiresDay].
final class KelopakVoucher {
  const KelopakVoucher({
    required this.id,
    required this.kind,
    required this.title,
    required this.amount,
    required this.minSpend,
    required this.issuedDay,
    required this.expiresDay,
    this.stageNumber,
    this.sourceOrderId,
    this.promoId,
    this.usedOnOrderId,
  });

  /// Voucher tahap [stage] untuk pesanan [sourceOrderId] pada [issuedDay].
  factory KelopakVoucher.mission({
    required String id,
    required MissionStage stage,
    required String sourceOrderId,
    required int issuedDay,
  }) => KelopakVoucher(
    id: id,
    kind: VoucherKind.mission,
    title: 'Voucher Misi Belanja ${stage.title}',
    amount: stage.voucherAmount,
    minSpend: stage.voucherMinSpend,
    issuedDay: issuedDay,
    expiresDay: issuedDay + stage.voucherValidDays,
    stageNumber: stage.number,
    sourceOrderId: sourceOrderId,
  );

  /// Membaca voucher misi tersimpan dari dokumen v2 (bentuk `MissionVoucher`).
  factory KelopakVoucher.fromMissionVoucher(MissionVoucher voucher) =>
      KelopakVoucher(
        id: voucher.id,
        kind: VoucherKind.mission,
        title: 'Voucher Misi Belanja Tahap ${voucher.stageNumber}',
        amount: voucher.amount,
        minSpend: voucher.minSpend,
        issuedDay: voucher.issuedDay,
        expiresDay: voucher.expiresDay,
        stageNumber: voucher.stageNumber,
        sourceOrderId: voucher.sourceOrderId,
        usedOnOrderId: voucher.usedOnOrderId,
      );

  /// Memulihkan voucher hasil [toJson]; melempar [FormatException] bila rusak.
  factory KelopakVoucher.fromJson(Object? source) {
    final json = asJsonMap(source, 'voucher');
    final voucher = KelopakVoucher(
      id: readString(json, 'id'),
      kind: readEnum(json, 'kind', VoucherKind.values),
      title: readString(json, 'title'),
      amount: readInt(json, 'amount'),
      minSpend: readInt(json, 'minSpend'),
      issuedDay: readInt(json, 'issuedDay'),
      expiresDay: readInt(json, 'expiresDay'),
      stageNumber: readOptionalInt(json, 'stageNumber'),
      sourceOrderId: readOptionalString(json, 'sourceOrderId'),
      promoId: readOptionalString(json, 'promoId'),
      usedOnOrderId: readOptionalString(json, 'usedOnOrderId'),
    );
    final missionOk =
        voucher.kind != VoucherKind.mission ||
        ((voucher.stageNumber ?? 0) >= 1 &&
            (voucher.sourceOrderId ?? '').isNotEmpty);
    final promoOk =
        voucher.kind != VoucherKind.promo || (voucher.promoId ?? '').isNotEmpty;
    if (voucher.id.isEmpty ||
        voucher.amount <= 0 ||
        voucher.minSpend < 0 ||
        voucher.expiresDay < voucher.issuedDay ||
        !missionOk ||
        !promoOk) {
      throw const FormatException('Voucher has impossible values');
    }
    return voucher;
  }

  /// ID unik: `VM-0001` (misi) atau `VP-0001` (promo).
  final String id;

  /// Asal voucher.
  final VoucherKind kind;

  /// Judul di kartu voucher.
  final String title;

  /// Nilai potongan dalam rupiah.
  final int amount;

  /// Minimal subtotal barang pesanan pemakainya, dalam rupiah.
  final int minSpend;

  /// Hari WIB voucher terbit.
  final int issuedDay;

  /// Hari WIB terakhir voucher bisa dipakai.
  final int expiresDay;

  /// Nomor tahap misi penerbit (hanya [VoucherKind.mission]).
  final int? stageNumber;

  /// Pesanan yang menyelesaikan tahap; voucher tidak bisa dipakai di pesanan
  /// itu (hanya [VoucherKind.mission]).
  final String? sourceOrderId;

  /// ID promo asal (hanya [VoucherKind.promo]).
  final String? promoId;

  /// Pesanan pemakai voucher, null selama belum dipakai.
  final String? usedOnOrderId;

  /// Apakah voucher sudah dipakai.
  bool get isUsed => usedOnOrderId != null;

  /// Apakah [today] sudah melewati [expiresDay].
  bool isExpiredOn(int today) => today > expiresDay;

  /// Apakah voucher belum dipakai dan belum kedaluwarsa pada [today].
  bool isActiveOn(int today) => !isUsed && !isExpiredOn(today);

  /// Bentuk `MissionVoucher` untuk aturan modul dan `VoucherCard`. Voucher
  /// promo memakai tahap 0 dan pesanan asal `promo:<id>`, yang tidak pernah
  /// sama dengan nomor pesanan.
  MissionVoucher get asMissionVoucher => MissionVoucher(
    id: id,
    stageNumber: stageNumber ?? 0,
    sourceOrderId: sourceOrderId ?? 'promo:${promoId ?? id}',
    amount: amount,
    minSpend: minSpend,
    issuedDay: issuedDay,
    expiresDay: expiresDay,
    usedOnOrderId: usedOnOrderId,
  );

  /// Mengapa voucher tidak bisa dipakai di [orderId] bersubtotal barang
  /// [subtotal] pada [today] (aturan modul), atau null bila bisa.
  RedeemProblem? problemFor({
    required String orderId,
    required int subtotal,
    required int today,
  }) => redeemProblem(
    voucher: asMissionVoucher,
    orderId: orderId,
    subtotal: subtotal,
    today: today,
  );

  /// Salinan yang tercatat dipakai di [orderId].
  KelopakVoucher markUsed(String orderId) => _copy(usedOnOrderId: orderId);

  /// Salinan yang kembali bisa dipakai (pesanan pemakainya batal); masa
  /// berlaku tidak berubah.
  KelopakVoucher release() => isUsed ? _copy(usedOnOrderId: null) : this;

  KelopakVoucher _copy({required String? usedOnOrderId}) => KelopakVoucher(
    id: id,
    kind: kind,
    title: title,
    amount: amount,
    minSpend: minSpend,
    issuedDay: issuedDay,
    expiresDay: expiresDay,
    stageNumber: stageNumber,
    sourceOrderId: sourceOrderId,
    promoId: promoId,
    usedOnOrderId: usedOnOrderId,
  );

  /// Menyerialkan voucher.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'title': title,
    'amount': amount,
    'minSpend': minSpend,
    'issuedDay': issuedDay,
    'expiresDay': expiresDay,
    'stageNumber': stageNumber,
    'sourceOrderId': sourceOrderId,
    'promoId': promoId,
    'usedOnOrderId': usedOnOrderId,
  };

  @override
  bool operator ==(Object other) =>
      other is KelopakVoucher &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.amount == amount &&
      other.minSpend == minSpend &&
      other.issuedDay == issuedDay &&
      other.expiresDay == expiresDay &&
      other.stageNumber == stageNumber &&
      other.sourceOrderId == sourceOrderId &&
      other.promoId == promoId &&
      other.usedOnOrderId == usedOnOrderId;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    amount,
    minSpend,
    issuedDay,
    expiresDay,
    stageNumber,
    sourceOrderId,
    promoId,
    usedOnOrderId,
  );

  @override
  String toString() =>
      'KelopakVoucher($id, ${kind.name}, $amount, min $minSpend, '
      'sampai $expiresDay, dipakai: $usedOnOrderId)';
}
