/// Format angka, uang, Kelopak, tanggal, dan hitung mundur (Indonesia).
///
/// Uang selalu lewat [rupiah] ("Rp10.000", tanpa spasi).
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDateOf, wibWeekdayOf;
import 'package:misi_belanja/misi_belanja.dart' show rupiah;

import 'units.dart' show rupiahPerKelopak;

export 'package:misi_belanja/misi_belanja.dart' show rupiah;

const List<String> _weekdayNames = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

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

/// Indonesian weekday of a WIB day: "Sabtu".
String weekdayName(int wibDay) => _weekdayNames[wibWeekdayOf(wibDay) - 1];

/// "Sabtu, 28 Nov 2026".
String wibDateLabel(int wibDay) {
  final date = wibDateOf(wibDay);
  return '${weekdayName(wibDay)}, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}

/// "28 Nov".
String shortDateLabel(int wibDay) {
  final date = wibDateOf(wibDay);
  return '${date.day} ${_monthNames[date.month - 1]}';
}

/// "2 hari 3 jam", "5 jam 12 menit", "45 menit" or "kurang dari 1 menit".
String countdownLabel(Duration remaining) {
  if (remaining < const Duration(minutes: 1)) return 'kurang dari 1 menit';
  final days = remaining.inDays;
  final hours = remaining.inHours % Duration.hoursPerDay;
  final minutes = remaining.inMinutes % Duration.minutesPerHour;
  if (days > 0) return hours > 0 ? '$days hari $hours jam' : '$days hari';
  if (hours > 0) {
    return minutes > 0 ? '$hours jam $minutes menit' : '$hours jam';
  }
  return '$minutes menit';
}
