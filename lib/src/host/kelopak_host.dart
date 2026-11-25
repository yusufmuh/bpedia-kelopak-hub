/// Antarmuka integrasi tunggal antara sistem Kelopak dan aplikasi induk.
///
/// Hub tidak mengenal login, katalog, keranjang, suara, analitik, maupun
/// notifikasi; semuanya datang lewat [KelopakHost]. Hub hanya memancarkan
/// [KelopakEvent]; aplikasi yang memetakannya ke analitik dan kotak masuk.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ImageProvider;

import '../controller/kelopak_event.dart';
import '../domain/checkout.dart';
import '../kit/game_cue.dart';

/// Data tampilan sebuah produk katalog (hadiah roda, hadiah hari ke-30,
/// produk misi). Harga hanya dari katalog host; hub tidak mengarangnya.
@immutable
final class KelopakProduct {
  const KelopakProduct({
    required this.code,
    required this.name,
    required this.price,
    this.image,
    this.strikePrice,
  });

  /// Kode produk katalog.
  final String code;

  /// Nama produk.
  final String name;

  /// Harga jual dalam rupiah.
  final int price;

  /// Foto produk; null bila host tidak punya gambarnya.
  final ImageProvider? image;

  /// Harga coret, bila ada.
  final int? strikePrice;

  @override
  bool operator ==(Object other) =>
      other is KelopakProduct &&
      other.code == code &&
      other.name == name &&
      other.price == price &&
      other.image == image &&
      other.strikePrice == strikePrice;

  @override
  int get hashCode => Object.hash(code, name, price, image, strikePrice);

  @override
  String toString() => 'KelopakProduct($code, $name, $price)';
}

/// Pengingat "Ingatkan saya" Roda Sabtu (Sabtu 09.00 WIB). Host yang
/// menjadwalkan notifikasinya; izin diminta saat dinyalakan.
abstract interface class KelopakReminder {
  /// False di platform tanpa notifikasi terjadwal (web): tombol disembunyikan.
  bool get isSupported;

  /// Apakah pengingat sedang terjadwal.
  Future<bool> isEnabled();

  /// Menyalakan atau mematikan pengingat. Mengembalikan keadaan sesudahnya
  /// (false bila izin ditolak).
  Future<bool> setEnabled(bool enabled);
}

/// Yang harus disediakan aplikasi induk.
///
/// Navigasi tidak menerima `BuildContext`: host memegang navigatornya
/// sendiri, sama seperti aksi di controller tiap modul game.
abstract class KelopakHost {
  /// Apakah pengguna sudah masuk. Tamu boleh melihat halaman hadiah, tetapi
  /// klaim, putar, dan checkout meminta masuk.
  bool get isLoggedIn;

  /// Memberi tahu saat login atau isi keranjang berubah, supaya halaman
  /// hadiah ikut diperbarui. Null bila host tidak pernah berubah.
  Listenable? get changes => null;

  /// Membuka halaman Masuk.
  void openLogin();

  /// Membuka etalase belanja.
  void openShop();

  /// Membuka keranjang.
  void openCart();

  /// Membuka detail produk [productCode].
  void openProduct(String productCode);

  /// Menambah [quantity] buah [productCode] ke keranjang. False bila gagal
  /// (stok habis, produk tidak ada).
  Future<bool> addToCart(String productCode, {int quantity = 1});

  /// Barang berbayar di keranjang saat ini, untuk progres Misi Belanja.
  List<CheckoutLine> get cartLines;

  /// Data tampilan produk [code], atau null bila tidak ada di katalog.
  KelopakProduct? productOf(String code);

  /// Memutar isyarat suara [cue] (mengikuti pengaturan suara host).
  void playCue(GameCue cue) {}

  /// Pengingat Roda Sabtu; null bila host tidak menyediakannya.
  KelopakReminder? get reminder => null;

  /// Menerima setiap peristiwa Kelopak (analitik, kotak masuk).
  void onEvent(KelopakEvent event) {}
}

/// Host di memori untuk `example/` dan tes: keranjang sederhana, katalog
/// dari peta, dan catatan navigasi.
class MemoryKelopakHost extends KelopakHost with ChangeNotifier {
  MemoryKelopakHost({
    Map<String, KelopakProduct> products = const <String, KelopakProduct>{},
    bool loggedIn = true,
    this.reminder,
  }) : _products = Map<String, KelopakProduct>.of(products),
       _loggedIn = loggedIn;

  final Map<String, KelopakProduct> _products;
  final Map<String, int> _cart = <String, int>{};
  bool _loggedIn;

  /// Navigasi yang diminta, berurutan: `login`, `shop`, `cart`,
  /// `product:<kode>`.
  final List<String> navigations = <String>[];

  /// Isyarat suara yang diminta, berurutan.
  final List<GameCue> cues = <GameCue>[];

  /// Peristiwa yang diterima, berurutan.
  final List<KelopakEvent> events = <KelopakEvent>[];

  @override
  final KelopakReminder? reminder;

  @override
  bool get isLoggedIn => _loggedIn;

  /// Mengubah status masuk dan memberi tahu pendengar.
  set isLoggedIn(bool value) {
    if (_loggedIn == value) return;
    _loggedIn = value;
    notifyListeners();
  }

  @override
  Listenable get changes => this;

  @override
  void openLogin() => navigations.add('login');

  @override
  void openShop() => navigations.add('shop');

  @override
  void openCart() => navigations.add('cart');

  @override
  void openProduct(String productCode) =>
      navigations.add('product:$productCode');

  @override
  Future<bool> addToCart(String productCode, {int quantity = 1}) async {
    if (quantity < 1 || !_products.containsKey(productCode)) return false;
    _cart[productCode] = (_cart[productCode] ?? 0) + quantity;
    notifyListeners();
    return true;
  }

  /// Mengosongkan keranjang (setelah checkout).
  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    notifyListeners();
  }

  @override
  List<CheckoutLine> get cartLines => <CheckoutLine>[
    for (final entry in _cart.entries)
      CheckoutLine(
        productCode: entry.key,
        unitPrice: _products[entry.key]!.price,
        quantity: entry.value,
      ),
  ];

  @override
  KelopakProduct? productOf(String code) => _products[code];

  @override
  void playCue(GameCue cue) => cues.add(cue);

  @override
  void onEvent(KelopakEvent event) => events.add(event);
}
