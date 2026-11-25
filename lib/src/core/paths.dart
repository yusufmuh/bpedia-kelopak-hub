/// Jalur rute zona Hadiah (SPEC-V3 §3). Satu sumber untuk tabel rute hub,
/// tautan notifikasi, dan deep link.
library;

/// Jalur `/hadiah/*`.
abstract final class KelopakPaths {
  /// Zona Hadiah.
  static const String rewards = '/hadiah';

  /// Check-in Harian.
  static const String checkIn = '/hadiah/checkin';

  /// Roda Sabtu.
  static const String wheel = '/hadiah/roda';

  /// Misi Belanja.
  static const String mission = '/hadiah/misi';

  /// Hadiahku (hadiah menunggu).
  static const String myGifts = '/hadiah/hadiahku';

  /// Voucher.
  static const String vouchers = '/hadiah/voucher';

  /// Riwayat Kelopak.
  static const String ledger = '/hadiah/riwayat';
}
