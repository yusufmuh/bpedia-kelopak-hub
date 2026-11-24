/// Copy shared by Beranda and the Hadiah screens about when the next
/// check-in and the next spin open, so every screen says the same thing,
/// also after the device clock was moved back.
library;

import 'package:misi_belanja/misi_belanja.dart' show MissionStage;

import '../../core/format.dart';
import '../../domain/app_state.dart';

/// Whether the last check-in is dated after today: the device clock was
/// moved back after a claim, so the next check-in opens later than tomorrow.
bool checkInDatedAhead(AppState app) => app.nextCheckInDay > app.today + 1;

/// When the next check-in opens: "Kembali besok mulai 00.00 WIB" followed by
/// [after] (e.g. "untuk Hari ke-5"), or the real date when the device clock
/// was moved back after a claim.
String checkInReturnLine(AppState app, {String after = ''}) {
  final tail = after.isEmpty ? '' : ' $after';
  if (!checkInDatedAhead(app)) return 'Kembali besok mulai 00.00 WIB$tail';
  return 'Check-in berikutnya ${shortDateLabel(app.nextCheckInDay)} mulai '
      '00.00 WIB$tail (tanggal perangkat berubah)';
}

/// Snack bar text when today's check-in is not available (already claimed,
/// or claimed for a later date before the device clock was moved back).
String checkInClosedMessage(AppState app) => checkInDatedAhead(app)
    ? '${checkInReturnLine(app)}.'
    : 'Kamu sudah check-in hari ini. Kembali besok mulai 00.00 WIB.';

/// Whether the last spin is dated after today (the device clock was moved
/// back after a spin).
bool spinDatedAhead(AppState app) {
  final last = app.lastSpin;
  return last != null && last.wibDay > app.today;
}

/// Title of a used Roda Sabtu: "Sudah diputar Sabtu ini", or the spin's own
/// date when it is dated after today.
String spinUsedTitle(AppState app) {
  final last = app.lastSpin;
  if (last != null && last.wibDay > app.today) {
    return 'Putaran Sabtu ${shortDateLabel(last.wibDay)} sudah tercatat';
  }
  return 'Sudah diputar Sabtu ini';
}

/// Misi Belanja note for a shipped order that qualifies for [stage] while
/// another shipped order qualifies too: only the first one received
/// completes the stage, so the voucher is not promised to this one.
String sharedStageNote(MissionStage stage) =>
    'Pesanan ini memenuhi syarat Misi Belanja tahap ${stage.number}. Satu '
    'pesanan menyelesaikan satu tahap, jadi voucher '
    '${rupiah(stage.voucherAmount)} terbit untuk pesanan memenuhi syarat '
    'yang lebih dulu diterima.';
