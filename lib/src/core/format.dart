/// Format angka, uang, Kelopak, dan tanggal (Indonesia).
///
/// Uang selalu lewat [rupiah] ("Rp10.000", tanpa spasi). Nama hari, tanggal
/// pendek, dan hitung mundur adalah milik `roda_sabtu` dan hanya diekspor
/// ulang di sini.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDateOf;
import 'package:misi_belanja/misi_belanja.dart' show rupiah;
import 'package:roda_sabtu/roda_sabtu.dart' show weekdayName;

import 'units.dart' show rupiahPerKelopak;

export 'package:misi_belanja/misi_belanja.dart' show rupiah;
export 'package:roda_sabtu/roda_sabtu.dart'
    show countdownLabel, shortDateLabel, weekdayName;

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Integer with dot thousands separators: `1250` gives "1.250", `-25000` gives "-25.000".
String groupThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// "12 Kelopak".
String kelopakLabel(int amount) => '${groupThousands(amount)} Kelopak';

/// "+3 Kelopak" for credits, "-5 Kelopak" for debits, "0 Kelopak".
String signedKelopakLabel(int amount) =>
    amount > 0 ? '+${kelopakLabel(amount)}' : kelopakLabel(amount);

/// Rupiah value of [amount] Kelopak: "Rp1.200".
String kelopakRupiah(int amount) => rupiah(amount * rupiahPerKelopak);

/// "12 Kelopak (Rp1.200)".
String kelopakWithRupiah(int amount) =>
    '${kelopakLabel(amount)} (${kelopakRupiah(amount)})';

/// "Sabtu, 28 Nov 2026".
String wibDateLabel(int wibDay) {
  final date = wibDateOf(wibDay);
  return '${weekdayName(wibDay)}, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}
