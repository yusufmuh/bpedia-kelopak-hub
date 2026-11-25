/// Buku besar Kelopak (Dart murni): setiap kredit dan debit, hanya bertambah.
///
/// Saldo selalu sama dengan jumlah semua entri dan tidak pernah negatif.
library;

import '../storage/json_reader.dart';

/// Asal sebuah entri buku besar.
enum LedgerKind {
  /// Kredit Check-in Harian (+1).
  checkIn('Check-in Harian'),

  /// Bonus rentetan hari ke-7, 14, 21, ... (+3).
  checkInBonus('Bonus rentetan'),

  /// Kelopak dari Roda Sabtu.
  spinPrize('Roda Sabtu'),

  /// Kelopak dipakai sebagai potongan belanja (jumlah negatif).
  checkoutSpend('Potongan belanja'),

  /// Kelopak dikembalikan karena pesanan dibatalkan.
  checkoutRefund('Pengembalian'),

  /// Saldo yang diisi lewat Mode Demo.
  demoGrant('Isi saldo (demo)');

  const LedgerKind(this.label);

  /// Label pendek untuk daftar riwayat.
  final String label;
}

/// Satu baris buku besar yang tidak berubah. [amount] positif untuk kredit,
/// negatif untuk debit.
final class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.wibDay,
    required this.amount,
    required this.kind,
    required this.note,
    this.orderId,
  });

  /// Memulihkan entri hasil [toJson]; melempar [FormatException] bila rusak.
  factory LedgerEntry.fromJson(Object? source) {
    final json = asJsonMap(source, 'ledger entry');
    return LedgerEntry(
      id: readString(json, 'id'),
      wibDay: readInt(json, 'wibDay'),
      amount: readInt(json, 'amount'),
      kind: readEnum(json, 'kind', LedgerKind.values),
      note: readString(json, 'note', fallback: ''),
      orderId: readOptionalString(json, 'orderId'),
    );
  }

  /// ID unik, misalnya `L000012`.
  final String id;

  /// Hari WIB (hari sejak 1 Jan 1970 WIB) saat entri dibukukan.
  final int wibDay;

  /// Jumlah Kelopak bertanda.
  final int amount;

  /// Asal entri.
  final LedgerKind kind;

  /// Keterangan yang tampil di "Riwayat Kelopak".
  final String note;

  /// Pesanan terkait untuk [LedgerKind.checkoutSpend] dan
  /// [LedgerKind.checkoutRefund]; null untuk entri lain dan entri v2.
  final String? orderId;

  /// True untuk kredit (jumlah > 0).
  bool get isCredit => amount > 0;

  /// Menyerialkan entri.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'wibDay': wibDay,
    'amount': amount,
    'kind': kind.name,
    'note': note,
    'orderId': orderId,
  };

  @override
  bool operator ==(Object other) =>
      other is LedgerEntry &&
      other.id == id &&
      other.wibDay == wibDay &&
      other.amount == amount &&
      other.kind == kind &&
      other.note == note &&
      other.orderId == orderId;

  @override
  int get hashCode => Object.hash(id, wibDay, amount, kind, note, orderId);
}

/// Entri buku besar beserta saldo tepat setelah entri itu dibukukan.
final class LedgerLine {
  const LedgerLine({required this.entry, required this.balanceAfter});

  /// Entri yang dibukukan.
  final LedgerEntry entry;

  /// Saldo berjalan termasuk [entry].
  final int balanceAfter;
}

/// Jumlah semua nilai di [entries].
int ledgerBalance(Iterable<LedgerEntry> entries) {
  var total = 0;
  for (final entry in entries) {
    total += entry.amount;
  }
  return total;
}

/// Riwayat dengan saldo berjalan, terbaru lebih dulu, dari [entries] yang
/// berurutan waktu.
List<LedgerLine> buildLedgerHistory(List<LedgerEntry> entries) {
  final lines = <LedgerLine>[];
  var running = 0;
  for (final entry in entries) {
    running += entry.amount;
    lines.add(LedgerLine(entry: entry, balanceAfter: running));
  }
  return lines.reversed.toList(growable: false);
}
