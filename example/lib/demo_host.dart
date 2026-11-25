import 'package:flutter/material.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import 'demo_pages.dart';

/// Pengingat di memori (contoh tidak menjadwalkan notifikasi sungguhan).
class DemoReminder implements KelopakReminder {
  bool _on = false;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isEnabled() async => _on;

  @override
  Future<bool> setEnabled(bool enabled) async => _on = enabled;
}

/// Host contoh: keranjang sederhana, katalog demo, navigasi ke halaman
/// contoh, dan catatan isyarat suara serta peristiwa untuk panel demo.
class DemoHost extends KelopakHost
    with ChangeNotifier
    implements KelopakGameActions {
  DemoHost({required this.products, required this.navigatorKey});

  /// Katalog demo.
  final Map<String, KelopakProduct> products;

  /// Navigator aplikasi contoh.
  final GlobalKey<NavigatorState> navigatorKey;

  final Map<String, int> _cart = <String, int>{};
  final DemoReminder _reminder = DemoReminder();
  bool _loggedIn = true;
  bool _soundOn = true;

  /// Isyarat suara dan peristiwa terakhir (terbaru dulu), untuk panel demo.
  final List<String> log = <String>[];

  @override
  bool get isLoggedIn => _loggedIn;

  set isLoggedIn(bool value) {
    if (value == _loggedIn) return;
    _loggedIn = value;
    notifyListeners();
  }

  @override
  Listenable get changes => this;

  /// Jumlah [code] di keranjang.
  int quantityOf(String code) => _cart[code] ?? 0;

  /// Isi keranjang.
  Map<String, int> get cart => Map<String, int>.unmodifiable(_cart);

  /// Mengosongkan keranjang setelah pesanan dibuat.
  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  void _push(Widget page) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => page),
  );

  @override
  void openLogin() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Contoh: masuk sebagai Babes (demo lokal).'),
        action: SnackBarAction(
          label: 'Masuk',
          onPressed: () => isLoggedIn = true,
        ),
      ),
    );
  }

  @override
  void openShop() => _push(const DemoShopPage());

  @override
  void openCart() => _push(const DemoCartPage());

  @override
  void openCheckout() => openCart();

  @override
  void openOrder(String orderId) => _push(const DemoOrdersPage());

  @override
  void openProduct(String productCode) {
    final context = navigatorKey.currentContext;
    final product = products[productCode];
    if (context == null || product == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} · ${rupiah(product.price)}')),
    );
  }

  @override
  Future<bool> addToCart(String productCode, {int quantity = 1}) async {
    if (quantity < 1 || !products.containsKey(productCode)) return false;
    _cart[productCode] = quantityOf(productCode) + quantity;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setCartQuantity(String productCode, int quantity) async {
    if (!products.containsKey(productCode)) return false;
    if (quantity <= 0) {
      _cart.remove(productCode);
    } else {
      _cart[productCode] = quantity;
    }
    notifyListeners();
    return true;
  }

  @override
  List<CheckoutLine> get cartLines => <CheckoutLine>[
    for (final entry in _cart.entries)
      CheckoutLine(
        productCode: entry.key,
        unitPrice: products[entry.key]!.price,
        quantity: entry.value,
      ),
  ];

  @override
  KelopakProduct? productOf(String code) => products[code];

  @override
  bool? get soundOn => _soundOn;

  @override
  void setSoundOn(bool value) {
    _soundOn = value;
    notifyListeners();
  }

  @override
  void playCue(GameCue cue) {
    if (_soundOn) _record('Suara: ${cue.name}');
  }

  @override
  KelopakReminder get reminder => _reminder;

  @override
  void onEvent(KelopakEvent event) {
    final notice = event.notice;
    _record(notice == null ? event.runtimeType.toString() : notice.title);
  }

  void _record(String line) {
    log.insert(0, line);
    if (log.length > 30) log.removeLast();
  }
}
