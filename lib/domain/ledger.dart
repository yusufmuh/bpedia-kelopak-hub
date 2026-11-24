/// Kelopak ledger (pure Dart): every credit and debit, append-only.
///
/// The balance is always the sum of all entry amounts and never negative.
library;

import 'json_reader.dart';

/// Rupiah value of one Kelopak (1 Kelopak = Rp100).
const int rupiahPerKelopak = 100;

/// What produced a ledger entry.
enum LedgerKind {
  /// Daily check-in credit (+1).
  checkIn('Check-in Harian'),

  /// Streak bonus on day 7, 14, 21, ... (+3).
  checkInBonus('Bonus rentetan'),

  /// Kelopak won on Roda Sabtu.
  spinPrize('Roda Sabtu'),

  /// Kelopak spent as a checkout discount (negative amount).
  checkoutSpend('Potongan belanja');

  const LedgerKind(this.label);

  /// Short Indonesian label for history lists.
  final String label;
}

/// One immutable ledger line. [amount] is positive for credits, negative for debits.
final class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.wibDay,
    required this.amount,
    required this.kind,
    required this.note,
  });

  /// Restores an entry written by [toJson]; throws [FormatException] on bad data.
  factory LedgerEntry.fromJson(Object? source) {
    final json = asJsonMap(source, 'ledger entry');
    return LedgerEntry(
      id: readString(json, 'id'),
      wibDay: readInt(json, 'wibDay'),
      amount: readInt(json, 'amount'),
      kind: readEnum(json, 'kind', LedgerKind.values),
      note: readString(json, 'note', fallback: ''),
    );
  }

  /// Unique id, e.g. `L000012`.
  final String id;

  /// WIB calendar day (days since 1970-01-01 WIB) the entry was booked.
  final int wibDay;

  /// Signed Kelopak amount.
  final int amount;

  /// Source of the entry.
  final LedgerKind kind;

  /// Indonesian description shown in "Riwayat Kelopak".
  final String note;

  /// True for credits (amount > 0).
  bool get isCredit => amount > 0;

  /// Serializes the entry.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'wibDay': wibDay,
    'amount': amount,
    'kind': kind.name,
    'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is LedgerEntry &&
      other.id == id &&
      other.wibDay == wibDay &&
      other.amount == amount &&
      other.kind == kind &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, wibDay, amount, kind, note);
}

/// A ledger entry together with the balance right after it was booked.
final class LedgerLine {
  const LedgerLine({required this.entry, required this.balanceAfter});

  /// The booked entry.
  final LedgerEntry entry;

  /// Running balance including [entry].
  final int balanceAfter;
}

/// Sum of all amounts in [entries].
int ledgerBalance(Iterable<LedgerEntry> entries) {
  var total = 0;
  for (final entry in entries) {
    total += entry.amount;
  }
  return total;
}

/// Running-balance history, newest first, from chronological [entries].
List<LedgerLine> buildLedgerHistory(List<LedgerEntry> entries) {
  final lines = <LedgerLine>[];
  var running = 0;
  for (final entry in entries) {
    running += entry.amount;
    lines.add(LedgerLine(entry: entry, balanceAfter: running));
  }
  return lines.reversed.toList(growable: false);
}
