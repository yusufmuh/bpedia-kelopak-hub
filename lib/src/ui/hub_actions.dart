/// Aksi hub yang memakai host: pakai voucher dan buka checkout.
library;

import '../controller/kelopak_controller.dart';
import '../games/game_actions.dart';

/// Voucher dipilih di checkout: buka checkout bila host menyediakannya,
/// selain itu keranjang.
void useVoucherFromHub(KelopakController controller) {
  final Object? host = controller.host;
  if (host is KelopakGameActions) {
    host.openCheckout();
  } else {
    controller.host?.openCart();
  }
}
