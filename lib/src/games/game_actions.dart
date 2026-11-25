/// Aksi tambahan yang boleh disediakan aplikasi induk untuk tiga game.
library;

/// Aksi opsional di luar `KelopakHost`. Host yang juga mengimplementasikan
/// antarmuka ini membuat tombol game lebih tepat sasaran; tanpa itu game
/// memakai jalan keluar yang aman (keranjang, tombol suara disembunyikan).
abstract interface class KelopakGameActions {
  /// Membuka checkout (Misi Belanja: "Checkout sekarang").
  void openCheckout();

  /// Membuka detail pesanan [orderId] (pesanan yang menunggu diterima).
  void openOrder(String orderId);

  /// Mengubah jumlah [productCode] di keranjang menjadi [quantity] (0 =
  /// hapus). False bila gagal.
  Future<bool> setCartQuantity(String productCode, int quantity);

  /// Status suara host; null menyembunyikan tombol suara di game.
  bool? get soundOn;

  /// Menyalakan atau mematikan suara host.
  void setSoundOn(bool value);
}

/// Tiga game di zona Hadiah.
enum KelopakGame {
  /// Check-in Harian.
  checkIn('Check-in Harian'),

  /// Roda Sabtu.
  wheel('Roda Sabtu'),

  /// Misi Belanja.
  mission('Misi Belanja');

  const KelopakGame(this.title);

  /// Nama tampil.
  final String title;
}
